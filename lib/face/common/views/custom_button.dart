import 'package:classcare/face/common/utils/extensions/size_extension.dart';
import 'package:classcare/face/theme.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05),
        decoration: BoxDecoration(
          color: onTap != null ? buttonColor : buttonColor.withOpacity(0.5),
          borderRadius:
              BorderRadius.circular(MediaQuery.of(context).size.height * 0.02),
        ),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width * 0.03),
                  child: Row(
                    children: [
                      if (icon != null)
                        Padding(
                          padding: EdgeInsets.only(
                              right: MediaQuery.of(context).size.width * 0.02),
                          child: Icon(icon,
                              color: primaryBlack,
                              size: MediaQuery.of(context).size.height * 0.025),
                        ),
                      Text(
                        text,
                        style: TextStyle(
                          color: primaryBlack,
                          fontSize: MediaQuery.of(context).size.height * 0.025,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              CircleAvatar(
                radius: MediaQuery.of(context).size.height * 0.03,
                backgroundColor:
                    onTap != null ? accentColor : accentColor.withOpacity(0.5),
                child: const Icon(
                  Icons.arrow_circle_right,
                  color: buttonColor,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
