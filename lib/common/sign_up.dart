import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/main.dart'; // To access global currentUser

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // --- STATE VARIABLES ---
  bool _isVerificationMailSent = false;
  bool _isLoading = false;
  Timer? _timer;

  // Default Role
  String _selectedRole = 'doctor'; // Options: 'doctor', 'patient'

  // --- CONTROLLERS ---
  // Common
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Doctor Specific
  final _specialtyController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _licenseController = TextEditingController();

  // Patient Specific
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _cnicController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  // Colors
  final Color primaryColor = const Color(0xFF2563EB); // Blue for Doctor
  final Color patientColor = const Color(0xFF009688); // Teal for Patient

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();

    _specialtyController.dispose();
    _hospitalController.dispose();
    _licenseController.dispose();

    _ageController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _cnicController.dispose();

    super.dispose();
  }

  // Helper for Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: _selectedRole == 'doctor' ? primaryColor : patientColor,
            colorScheme: ColorScheme.light(primary: _selectedRole == 'doctor' ? primaryColor : patientColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // ==========================================
  // PHASE 1: CREATE ACCOUNT & SEND EMAIL
  // ==========================================
  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _phoneController.text.isEmpty) {
      _showMessage("Please fill in Name, Email, Password and Phone (*)", Colors.red);
      return;
    }

    if (_selectedRole == 'patient') {
      if (_cnicController.text.isEmpty || _cityController.text.isEmpty) {
        _showMessage("Patients must provide CNIC and City", Colors.red);
        return;
      }
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match", Colors.red);
      return;
    }

    if (!_agreedToTerms) {
      _showMessage("Please agree to the Terms of Service", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        if (!user.emailVerified) {
          await user.sendEmailVerification();
          setState(() {
            _isVerificationMailSent = true;
            _isLoading = false;
          });
          _startVerificationCheck();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showMessage(e.message ?? "An error occurred", Colors.red);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error: $e", Colors.red);
    }
  }

  // ==========================================
  // PHASE 2: CHECK VERIFICATION & SAVE DATA
  // ==========================================
  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      var user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        timer.cancel();
        _saveDataAndNavigate(user);
      }
    });
  }

  Future<void> _manualVerificationCheck() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      _saveDataAndNavigate(user);
    } else {
      setState(() => _isLoading = false);
      _showMessage("Email not verified yet.", Colors.orange);
    }
  }

  // --- MAIN UPDATED LOGIC ---
  Future<void> _saveDataAndNavigate(User user) async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> userData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'doctor') {
        userData['specialty'] = _specialtyController.text.trim();
        userData['hospital'] = _hospitalController.text.trim();
        userData['license'] = _licenseController.text.trim();
      } else {
        userData['age'] = _ageController.text.trim();
        userData['dob'] = _dobController.text.trim();
        userData['city'] = _cityController.text.trim();
        userData['address'] = _addressController.text.trim();
        userData['cnic'] = _cnicController.text.trim();
        userData['medicalHistory'] = [];
      }

      // Save to Firestore 'users'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData);

      // Update Global User
      currentUser = user;

      if (mounted) {
        _showMessage("Account Verified & Setup Complete!", Colors.green);

        if (_selectedRole == 'patient') {
          Navigator.pushNamedAndRemoveUntil(context, '/patient_home', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } catch (e) {
      _showMessage("Error saving profile: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color activeColor = _selectedRole == 'doctor' ? primaryColor : patientColor;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _isVerificationMailSent
              ? _buildVerificationUI()
              : _buildSignupForm(activeColor),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildSignupForm(Color activeColor) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.health_and_safety_outlined, size: 60, color: activeColor),
        const SizedBox(height: 10),
        const Text("Endoscopy AI Portal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 30),

        // Toggle Button
        _buildRoleSelector(),
        const SizedBox(height: 25),

        Text(
            _selectedRole == 'doctor' ? "Doctor Registration" : "Patient Registration",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: activeColor)
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Account Info", activeColor),
              _buildTextField(_nameController, "Full Name *", Icons.person_outline),
              const SizedBox(height: 12),
              _buildTextField(_emailController, "Email Address *", Icons.email_outlined, TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField(_phoneController, "Phone Number *", Icons.phone_outlined, TextInputType.phone),

              const SizedBox(height: 20),

              if (_selectedRole == 'doctor') ...[
                _buildSectionTitle("Professional Profile", activeColor),
                _buildTextField(_specialtyController, "Specialty", Icons.science_outlined),
                const SizedBox(height: 12),
                _buildTextField(_hospitalController, "Hospital / Clinic", Icons.local_hospital_outlined),
                const SizedBox(height: 12),
                _buildTextField(_licenseController, "Medical License ID", Icons.badge_outlined),
              ] else ...[
                _buildSectionTitle("Personal Details", activeColor),

                Row(
                  children: [
                    Expanded(child: _buildTextField(_ageController, "Age", Icons.calendar_view_day, TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: _buildTextField(_dobController, "DOB", Icons.cake_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(_cnicController, "CNIC Number", Icons.credit_card, TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(_cityController, "City", Icons.location_city),
                const SizedBox(height: 12),
                _buildTextField(_addressController, "Full Address", Icons.home_outlined),
              ],

              const SizedBox(height: 20),
              _buildSectionTitle("Security", activeColor),
              _buildPasswordField(_passwordController, "Password *", _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
              const SizedBox(height: 12),
              _buildPasswordField(_confirmPasswordController, "Confirm Password *", _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),

              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                      value: _agreedToTerms,
                      activeColor: activeColor,
                      onChanged: (val) => setState(() => _agreedToTerms = val!)
                  ),
                  const Expanded(child: Text("I agree to the Terms of Service.", style: TextStyle(fontSize: 12))),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Register as ${_selectedRole == 'doctor' ? 'Doctor' : 'Patient'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Already have an account? Login", style: TextStyle(color: activeColor)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildRoleTab("Doctor", 'doctor'),
          _buildRoleTab("Patient", 'patient'),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String label, String role) {
    bool isSelected = _selectedRole == role;
    Color color = role == 'doctor' ? primaryColor : patientColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationUI() {
    return Column(
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.orange),
        const SizedBox(height: 24),
        const Text("Verify Your Email", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text("We've sent a link to ${_emailController.text}.", textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(
          width: 200, height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _manualVerificationCheck,
            style: ElevatedButton.styleFrom(backgroundColor: _selectedRole == 'doctor' ? primaryColor : patientColor),
            child: const Text("I've Verified", style: TextStyle(color: Colors.white)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _isVerificationMailSent = false),
          child: const Text("Change Email", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // --- UPDATED TEXT FIELD WITH VISIBLE BORDER ---
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, [TextInputType type = TextInputType.text]) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey[50], // Light background
        enabledBorder: OutlineInputBorder( // Visible Border when not focused
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder( // Border when focused
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _selectedRole == 'doctor' ? primaryColor : patientColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, bool isObscured, VoidCallback onToggle) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility), onPressed: onToggle),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _selectedRole == 'doctor' ? primaryColor : patientColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}