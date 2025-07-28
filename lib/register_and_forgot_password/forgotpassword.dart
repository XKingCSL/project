import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  const ForgotPasswordPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  Future<void> _handleForgotPassword() async {
    String email = emailController.text.trim();
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ກະລຸນາໃສ່ອີເມວ')));
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ຮູບແບບອີເມວບໍ່ຖືກຕ້ອງ')));
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ກະລຸນາກວດສອບອີເມວຂອງທ່ານ')));
      Navigator.pop(context);
    } on FirebaseAuthException {
      String msg = 'ບໍ່ສາມາດສົ່ງຄຳຮ້ອງຂໍໄດ້';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
              const SizedBox(height: 30),
              Text(
                'ລືມລະຫັດຜ່ານ',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'ກະລຸນາໃສ່ອີເມວທີ່ທ່ານໃຊ້ລົງທະບຽນ ເພື່ອຮັບລິ້ງສຳລັບການຕັ້ງຄ່າລະຫັດຜ່ານໃໝ່',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.red : Colors.grey[900],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'ອີເມວ',
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) {
                  if (!isLoading) _handleForgotPassword();
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading ? null : _handleForgotPassword,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'ສົ່ງຄຳຮ້ອງຂໍ',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'ກັບໄປໜ້າ Login',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
