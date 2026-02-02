// screens/contact_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/contacts_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'about_us_screen.dart';
import '../widgets/app_bottom_navigation.dart';

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
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: const Text(
          'Contact Details',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/background_1.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          top: kToolbarHeight + MediaQuery.of(context).padding.top,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: _buildBody(),
          ),
        ),
      ],
    ),
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 3),
  );
}

/*   @override
  Widget build(BuildContext context) {
    return Scaffold(
      //extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white /*Colors.black87*/),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Contact Details',
          style: TextStyle(
            //color: Colors.black87,
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body:Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.7),
              BlendMode.lighten,
              ),
            ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 3),
    );
  } */

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.description != null &&
                  group.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  group.description!,
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
              Text(
                group.name,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Inter',
                  
                  color: Colors.black87,
                ),
              ),
              
            ],
          ),
        ),

        // Contacts in this group
        ...group.contacts.map((contact) => _buildContactCard(contact)),

        const SizedBox(height: 0),
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
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                backgroundImage:
                    contact.avatar != null && contact.avatar!.isNotEmpty
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
                          fontSize: 14,
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
                          fontSize: 12,
                          fontFamily: 'Inter',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    if (contact.timezone != null &&
                        contact.timezone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Time zone ${contact.timezone}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Inter',
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                    if (contact.email != null && contact.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${contact.email}',
                        style: TextStyle(
                          fontSize: 12,
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
          
          // Espacio de separación entre email y botones de contacto
          const SizedBox(height: 12),
          
          // Contact Actions (only show if phone or email exists)
          if ((contact.phone != null && contact.phone!.isNotEmpty) ||
              (contact.email != null && contact.email!.isNotEmpty)) ...[
            Row(
              children: [
                if (contact.phone != null && contact.phone!.isNotEmpty)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.phone,
                      label: 'Contact',
                      // onTap: () => (),
                      // info: contact.phone!,
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
    String? info,
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
          mainAxisSize: MainAxisSize.min,
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
            // if (info != null && info!.isNotEmpty) ...[
            //   const SizedBox(height: 2),
            //   Text(
            //     info!,
            //     style: TextStyle(
            //       fontSize: 10,
            //       fontFamily: 'Inter',
            //       color: Colors.grey[600],
            //     ),
            //     maxLines: 1,
            //     overflow: TextOverflow.ellipsis,
            //   ),
            // ],
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

  
}
