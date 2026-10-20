import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class ProfileSelectionPage extends ConsumerStatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  ConsumerState<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends ConsumerState<ProfileSelectionPage> {
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _checkAndSeedDatabase();
  }

  Future<void> _checkAndSeedDatabase() async {
    setState(() => _isSeeding = true);
    // Seed initial setup (creating default family/members/locations)
    final familyId = await apiService.triggerSetup();
    ref.read(familyIdProvider.notifier).state = familyId;
    ref.invalidate(membersProvider); // Force reload members list
    setState(() => _isSeeding = false);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219), // Ultra-premium dark slate
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Who\'s Using the App?',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a family member profile to begin tracking inventory.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Google Ecosystem OAuth Sign In
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.account_circle, color: Colors.blueAccent, size: 24),
                label: Text(
                  'Sign in with Google Account',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => _showGoogleSignInDialog(context),
              ),
              const SizedBox(height: 40),
              if (_isSeeding)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.indigoAccent),
                    SizedBox(height: 16),
                    Text(
                      'Initializing default family database...',
                      style: TextStyle(color: Colors.white70),
                    )
                  ],
                )
              else
                membersAsync.when(
                  data: (members) => _buildProfileGrid(context, members),
                  loading: () => const CircularProgressIndicator(color: Colors.indigoAccent),
                  error: (err, stack) => Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileGrid(BuildContext context, List<Member> members) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 24,
      children: [
        ...members.map((member) => _buildProfileCard(context, member)),
        // Add Profile Button
        _buildAddProfileButton(context),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, Member member) {
    final parsedColor = _parseHexColor(member.color);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _handleProfileTap(context, member),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: parsedColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: parsedColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  member.name.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (member.hasPincode) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.lock, size: 14, color: Colors.white54),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGoogleSignInDialog(BuildContext context) {
    final emailController = TextEditingController();
    String errorText = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text('Google Sign In', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your Google account email to sign in to your family profile:',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Google Email Address',
                  labelStyle: const TextStyle(color: Colors.white60),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.indigoAccent), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (errorText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                )
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  setDialogState(() => errorText = '');
                  try {
                    final member = await apiService.googleLogin(email, "google_oauth_mock_id");
                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      _loginAs(member);
                    }
                  } catch (e) {
                    setDialogState(() {
                      errorText = 'No matching member profile found for this Google email.';
                    });
                  }
                }
              },
              child: const Text('Sign In'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAddProfileButton(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showAddProfileDialog(context),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  size: 40,
                  color: Colors.white38,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Profile',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProfileTap(BuildContext context, Member member) async {
    if (member.hasPincode) {
      _showPinDialog(context, member);
    } else {
      _loginAs(member);
    }
  }

  void _loginAs(Member member) {
    ref.read(activeMemberProvider.notifier).selectProfile(member);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _showPinDialog(BuildContext context, Member member) {
    final pinController = TextEditingController();
    String errorText = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Enter PIN for ${member.name}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.indigoAccent),
                  ),
                ),
              ),
              if (errorText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                )
              ]
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final success = await apiService.verifyPin(member.id, pinController.text);
                if (success) {
                  Navigator.pop(context);
                  _loginAs(member);
                } else {
                  setDialogState(() {
                    errorText = 'Incorrect PIN code';
                    pinController.clear();
                  });
                }
              },
              child: const Text('Unlock'),
            )
          ],
        ),
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final pinController = TextEditingController();
    String selectedHexColor = '#3F51B5';

    final presetColors = [
      '#3F51B5', // Indigo
      '#E91E63', // Pink
      '#9C27B0', // Purple
      '#FF9800', // Orange
      '#009688', // Teal
      '#4CAF50', // Green
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Family Member Profile', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.indigoAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address (For Google Sign-In)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.indigoAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'PIN Code (Optional)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    helperText: '4-digit code to protect profile selection',
                    helperStyle: const TextStyle(color: Colors.white30),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.indigoAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Color Theme', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: presetColors.map((colorHex) {
                    final color = _parseHexColor(colorHex);
                    final isSelected = selectedHexColor == colorHex;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedHexColor = colorHex;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : Border.all(color: Colors.transparent),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)]
                              : [],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final pin = pinController.text.trim().isEmpty ? null : pinController.text.trim();
                  final email = emailController.text.trim().isEmpty ? null : emailController.text.trim();
                  await ref.read(membersProvider.notifier).addMember(name, selectedHexColor, pin, email);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            )
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.indigoAccent;
    }
  }
}
