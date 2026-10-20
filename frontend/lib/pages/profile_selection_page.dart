import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
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
    final familyId = await apiService.triggerSetup();
    ref.read(familyIdProvider.notifier).state = familyId;
    ref.invalidate(membersProvider);
    setState(() => _isSeeding = false);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            tooltip: 'API 伺服器網址設定',
            onPressed: () => _showServerSettingsDialog(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '誰正在使用？',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '選擇家庭成員頭像即可開始借還與管理家庭庫存',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                  '以 Google 帳號快速登入',
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
                      '正在連接資料庫並同步家庭資料庫...',
                      style: TextStyle(color: Colors.white70),
                    )
                  ],
                )
              else
                membersAsync.when(
                  data: (members) => _buildProfileGrid(context, members),
                  loading: () => const CircularProgressIndicator(color: Colors.indigoAccent),
                  error: (err, stack) => Column(
                    children: [
                      Text('連線或載入失敗: $err', style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _checkAndSeedDatabase,
                        child: const Text('重試連線'),
                      )
                    ],
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
        _buildAddProfileButton(context),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, Member member) {
    final parsedColor = parseHexColor(member.color);

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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: parsedColor.withOpacity(0.35),
                    blurRadius: 16,
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
                    fontWeight: FontWeight.w600,
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

  Widget _buildAddProfileButton(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showAddMemberDialog(context),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: const Icon(Icons.add, size: 40, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Text(
              '新增成員',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProfileTap(BuildContext context, Member member) {
    if (member.hasPincode) {
      _showPinDialog(context, member);
    } else {
      _enterHome(member);
    }
  }

  void _enterHome(Member member) {
    ref.read(activeMemberProvider.notifier).selectProfile(member);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _showPinDialog(BuildContext context, Member member) {
    final pinController = TextEditingController();
    String error = '';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          title: Text('${member.name} 的安全 PIN 碼', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 24),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final isValid = await apiService.verifyPin(member.id, pinController.text.trim());
                if (isValid) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _enterHome(member);
                } else {
                  setDialogState(() => error = 'PIN 碼錯誤，請重新輸入');
                }
              },
              child: const Text('確認'),
            )
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          title: const Text('Google 帳號快速登入', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Google Email',
                  hintText: 'edward@example.com',
                ),
              ),
              if (errorText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                try {
                  final member = await apiService.googleLogin(email, "google-sim-$email");
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _enterHome(member);
                } catch (e) {
                  setDialogState(() => errorText = '找不到此 Email 綁定的家庭成員: $e');
                }
              },
              child: const Text('登入'),
            )
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final emailController = TextEditingController();
    String selectedColor = '#3F51B5';

    final colors = ['#3F51B5', '#E91E63', '#9C27B0', '#FF9800', '#4CAF50', '#00BCD4', '#F44336'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          title: const Text('新增家庭成員', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '姓名 / 暱稱'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Google Email (選填)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: '設定 4 碼 PIN 鎖 (選填)'),
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('選擇代表顏色:', style: TextStyle(color: Colors.white60))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: colors.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: parseHexColor(c),
                        child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(membersProvider.notifier).addMember(
                  name,
                  selectedColor,
                  pinController.text.trim().isEmpty ? null : pinController.text.trim(),
                  emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            )
          ],
        ),
      ),
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final urlController = TextEditingController(text: ApiService.baseUrl);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('後端 API 伺服器網址', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本機測試預設為 http://10.0.2.2:8000 (模擬器) 或 http://localhost:8000。\n若部署至 Google Cloud Run，請在此貼上 Cloud Run 產生的 HTTPS 網址：',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://home-inventory-xxx.a.run.app',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                apiService.updateBaseUrl(newUrl);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _checkAndSeedDatabase();
              }
            },
            child: const Text('套用並連線'),
          )
        ],
      ),
    );
  }
}
