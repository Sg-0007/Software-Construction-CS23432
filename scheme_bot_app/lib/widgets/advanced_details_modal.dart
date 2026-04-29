import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdvancedDetailsModal extends StatefulWidget {
  final String? initialIncome;
  final String? initialEmployment;
  final String? initialDisability;

  const AdvancedDetailsModal({
    Key? key,
    this.initialIncome,
    this.initialEmployment,
    this.initialDisability,
  }) : super(key: key);

  @override
  _AdvancedDetailsModalState createState() => _AdvancedDetailsModalState();
}

class _AdvancedDetailsModalState extends State<AdvancedDetailsModal> {
  String? _income;
  String? _employment;
  String? _disability;

  final List<String> _incomes = ['Below 1 Lakh', '1 - 3 Lakhs', 'Above 3 Lakhs'];
  final List<String> _employments = ['Student', 'Unemployed', 'Self-Employed', 'Salaried'];
  final List<String> _disabilities = ['None', 'Physical', 'Visual', 'Other'];

  @override
  void initState() {
    super.initState();
    if (_incomes.contains(widget.initialIncome)) _income = widget.initialIncome;
    if (_employments.contains(widget.initialEmployment)) _employment = widget.initialEmployment;
    if (_disabilities.contains(widget.initialDisability)) _disability = widget.initialDisability;
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Text(
            'Advanced Details',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildDropdown(
            value: _income,
            items: _incomes,
            label: 'Annual Income',
            onChanged: (val) => setState(() => _income = val),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            value: _employment,
            items: _employments,
            label: 'Employment Status',
            onChanged: (val) => setState(() => _employment = val),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            value: _disability,
            items: _disabilities,
            label: 'Disability Status',
            onChanged: (val) => setState(() => _disability = val),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context, {
                'annual_income': _income,
                'employment_status': _employment,
                'disability_status': _disability,
              });
            },
            child: Text('Save & Close', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
