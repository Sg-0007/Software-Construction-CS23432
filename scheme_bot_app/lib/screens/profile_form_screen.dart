import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../widgets/advanced_details_modal.dart';
import 'chat_screen.dart';
import '../models/message.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({Key? key}) : super(key: key);

  @override
  _ProfileFormScreenState createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _educationController = TextEditingController();
  
  int? _calculatedAge;
  
  String? _selectedGender;
  String? _selectedState;
  String? _selectedCategory;
  
  String? _annualIncome;
  String? _employmentStatus;
  String? _disabilityStatus;
  
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile['full_name']?.toString() ?? '';
          
          if (profile['age'] != null && profile['age'] > 0) {
            _calculatedAge = profile['age'] as int;
            _dobController.text = 'Pre-calculated Age: $_calculatedAge';
          }
          
          if (_genders.contains(profile['gender'])) _selectedGender = profile['gender'];
          if (_states.contains(profile['state'])) _selectedState = profile['state'];
          if (_categories.contains(profile['category'])) _selectedCategory = profile['category'];
          
          _educationController.text = profile['education_level']?.toString() ?? '';
          
          _annualIncome = profile['annual_income']?.toString();
          _employmentStatus = profile['employment_status']?.toString();
          _disabilityStatus = profile['disability_status']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    if (birthDate.month > currentDate.month || (birthDate.month == currentDate.month && birthDate.day > currentDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _showEducationSheet() async {
    final List<String> options = ['10th Pass', '12th Pass', 'Diploma', 'Undergraduate', 'Postgraduate'];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Education Level', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ...options.map((option) => ListTile(
                    title: Text(option, style: GoogleFonts.inter()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(ctx, option),
                  )),
            ],
          ),
        );
      },
    );

    if (result != null) {
      if (mounted) setState(() => _educationController.text = result);
    }
  }

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _categories = ['General', 'OBC', 'SC', 'ST'];
  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final profileData = {
        'name': _nameController.text.trim(),
        'age': _calculatedAge?.toString() ?? '0',
        'gender': _selectedGender,
        'state': _selectedState,
        'category': _selectedCategory,
        'education': _educationController.text.trim(),
        'caste': _selectedCategory, 
        'income': _annualIncome ?? 'Not specified',
        'occupation': _employmentStatus ?? 'Not specified',
      };

      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        
        await Supabase.instance.client.from('profiles').upsert({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'age': _calculatedAge ?? 0,
          'gender': _selectedGender,
          'state': _selectedState,
          'category': _selectedCategory,
          'education_level': _educationController.text.trim(),
          'annual_income': _annualIncome,
          'employment_status': _employmentStatus,
          'disability_status': _disabilityStatus,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save profile securely: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      try {
        final result = await ApiService.submitProfile(profileData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile Updated Successfully'), backgroundColor: Colors.green),
          );
          
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            final initialMessage = Message(
              text: result['text'] ?? 'Profile successfully updated! Here are some schemes.',
              isUser: false,
              schemes: result['schemes'],
            );
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(initialMessage: initialMessage),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isInitializing 
        ? Center(child: SpinKitThreeBounce(color: Theme.of(context).primaryColor, size: 24))
        : SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: DefaultTextStyle(
            style: GoogleFonts.inter(color: Colors.black87),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Unlock specific government schemes by providing your details natively below.',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      _buildTextField(
                        controller: _nameController, 
                        label: 'Full Name', 
                        icon: Icons.person
                      ),
                      const SizedBox(height: 16),
                      
                      _buildReadOnlyField(
                        controller: _dobController,
                        label: 'Date of Birth',
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 6570)),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (date != null && mounted) {
                            setState(() {
                              _calculatedAge = _calculateAge(date);
                              const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              _dobController.text = '${months[date.month - 1]} ${date.day}, ${date.year} (Age: $_calculatedAge)';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        value: _selectedGender,
                        items: _genders,
                        label: 'Gender',
                        icon: Icons.people,
                        onChanged: (val) => setState(() => _selectedGender = val as String?),
                      ),
                      const SizedBox(height: 16),

                      _buildDropdown(
                        value: _selectedState,
                        items: _states,
                        label: 'State',
                        icon: Icons.map,
                        onChanged: (val) => setState(() => _selectedState = val as String?),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        value: _selectedCategory,
                        items: _categories,
                        label: 'Category',
                        icon: Icons.group,
                        onChanged: (val) => setState(() => _selectedCategory = val as String?),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildReadOnlyField(
                        controller: _educationController, 
                        label: 'Education Level', 
                        icon: Icons.school,
                        onTap: _showEducationSheet,
                      ),
                      const SizedBox(height: 24),
                      
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune, color: Colors.indigo),
                        label: Text('Add Advanced Details (Optional)', style: GoogleFonts.inter(color: Colors.indigo)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.indigo),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final result = await showModalBottomSheet<Map<String, dynamic>>(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (ctx) => AdvancedDetailsModal(
                              initialIncome: _annualIncome,
                              initialEmployment: _employmentStatus,
                              initialDisability: _disabilityStatus,
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _annualIncome = result['annual_income'] as String?;
                              _employmentStatus = result['employment_status'] as String?;
                              _disabilityStatus = result['disability_status'] as String?;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                            ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                            : Text(
                                'Find Eligible Schemes',
                                style: GoogleFonts.inter(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please select $label' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo),
        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter $label' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(dynamic) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select $label' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
