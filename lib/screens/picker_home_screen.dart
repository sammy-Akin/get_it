import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PickerHomeScreen extends StatelessWidget {
  const PickerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const Center(
        child: Text(
          'Picker Dashboard — Coming Soon',
          style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}
