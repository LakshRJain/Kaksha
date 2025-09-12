import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/theme.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final GlobalKey formFieldKey;
  final String validatorText;

  const CustomTextField({
    super.key,
    required this.formFieldKey,
    required this.controller,
    required this.hintText,
    required this.validatorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.055,
          vertical: MediaQuery.of(context).size.height * 0.02),
      child: TextFormField(
          key: formFieldKey,
          controller: controller,
          cursorColor: primaryBlack.withOpacity(0.8),
          style: const TextStyle(
            color: primaryBlack,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
          decoration: InputDecoration(
            hintText: hintText,
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return "Name cannot be empty";
            } else {
              return null;
            }
          }),
    );
  }
}
