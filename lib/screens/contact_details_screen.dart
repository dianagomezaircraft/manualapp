// screens/contact_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/contacts_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ContactDetailsScreen extends StatefulWidget {
  const ContactDetailsScreen({super.key});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  int selectedBottomIndex = 3; // Phone icon selected

  final ContactsService _contactsService = ContactsService();
  final AuthService _authService = AuthService();

  List<ContactGroup> contactGroups = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContactGroups();
  }

  Future<void> _loadContactGroups() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _contactsService.getContactGroups();

    if (!mounted) return;

    if (result['success'] == true) {
      final groupsData = result['data'] as List<dynamic>;
      setState(() {
        contactGroups = groupsData
            .map((json) => ContactGroup.fromJson(json as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)); // Sort by order
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = result['error'] ?? 'Failed to load contacts';
        isLoading = false;
      });

      // If authentication failed, redirect to login
      if (result['needsLogin'] == true) {
        _handleLogout();
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Contact Details',
          style: TextStyle(
            color: Colors.black87,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF123157),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContactGroups,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF123157),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (contactGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.contacts_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No contacts available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContactGroups,
      color: const Color(0xFF123157),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contactGroups.map((group) {
            return _buildContactGroup(group);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContactGroup(ContactGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.grey[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              if (group.description != null && group.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  group.description!,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Contacts in this group
        ...group.contacts.map((contact) => _buildContactCard(contact)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildContactCard(Contact contact) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Position with Avatar
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF123157),
                backgroundImage: contact.avatar != null && contact.avatar!.isNotEmpty
                    ? NetworkImage(contact.avatar!)
                    : null,
                child: contact.avatar == null || contact.avatar!.isEmpty
                    ? Text(
                        _getInitials(contact.firstName, contact.lastName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.black87,
                      ),
                    ),
                    if (contact.title != null && contact.title!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.title!,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Inter',
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (contact.phone != null && contact.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.phone!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Inter',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    if (contact.timezone != null && contact.timezone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Time zone ${contact.timezone}',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Inter',
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Contact Actions (only show if phone or email exists)
          if ((contact.phone != null && contact.phone!.isNotEmpty) ||
              (contact.email != null && contact.email!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (contact.phone != null && contact.phone!.isNotEmpty)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.phone,
                      label: 'Free call',
                      info: contact.phone!,
                      onTap: () => _makePhoneCall(contact.phone!),
                    ),
                  ),
                if (contact.phone != null &&
                    contact.phone!.isNotEmpty &&
                    contact.email != null &&
                    contact.email!.isNotEmpty)
                  const SizedBox(width: 12),
                if (contact.email != null && contact.email!.isNotEmpty)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      info: contact.email!,
                      onTap: () => _sendEmail(contact.email!),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String info,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF123157), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                color: Color(0xFF123157),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              info,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Inter',
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home_outlined, 0),
              _buildBottomNavItem(Icons.search, 1),
              _buildBottomNavItemARTS(2),
              _buildBottomNavItem(Icons.phone_outlined, 3),
              _buildBottomNavItem(Icons.more_horiz, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
        if (index == 3) {
          // Already on contact details
        } else if (index == 0) {
          Navigator.pop(context); // Go back to home
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF123157) : Colors.grey,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildBottomNavItemARTS(int index) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
        Navigator.pop(context); // Go back to home (ARTS screen)
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Image.asset(
              'assets/logoBlue.png',
              width: 73,
              height: 72,
            ),
          ],
        ),
      ),
    );
  }
}