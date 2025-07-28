import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  const RegisterPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isObscure = true;
  bool isLoading = false;

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
              const Icon(Icons.person_add_alt_1, size: 80, color: Colors.blue),
              const SizedBox(height: 25),
              Text(
                'ລົງທະບຽນ',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'ຊື່',
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'ອີເມວ',
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: isObscure,
                decoration: InputDecoration(
                  labelText: 'ລະຫັດຜ່ານ',
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isObscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        isObscure = !isObscure;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) {
                  if (!isLoading) _handleRegister();
                },
              ),
              const SizedBox(height: 32),
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
                  onPressed: isLoading ? null : _handleRegister,
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
                          'ສະໝັກສະມາຊິກ',
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
                    fontSize: 16,
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

  Future<void> _handleRegister() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ກະລຸນາໃສ່ຂໍ້ມູນໃຫ້ຄົບຖ້ວນ')),
      );
      return;
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ຮູບແບບອີເມວບໍ່ຖືກຕ້ອງ')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວອັກສອນ')),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ສຳເລັດການລົງທະບຽນ')));
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'ລົງທະບຽນບໍ່ສຳເລັດ';
      if (e.code == 'email-already-in-use') {
        msg = 'ອີເມວນີ້ຖືກໃຊ້ແລ້ວ';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
