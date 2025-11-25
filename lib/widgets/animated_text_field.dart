import 'package:flutter/material.dart';
import 'package:carbeat/constants/styles.dart';

class AnimatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool isPasswordField;
  final int maxLines;

  const AnimatedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.isPasswordField = false,
    this.maxLines = 1,
  });

  @override
  AnimatedTextFieldState createState() => AnimatedTextFieldState();
}

class AnimatedTextFieldState extends State<AnimatedTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
        decoration: BoxDecoration(
          color: Styles().primaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isFocused
                ? Styles().titleColor
                : Styles().titleColor.withOpacity(0.3),
            width: _isFocused ? 2 : 1,
                  ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                maxLines: widget.maxLines,
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                obscureText: widget.isPasswordField,
                cursorColor: Styles().titleColor,
                style: TextStyle(
                  color: Styles().titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  labelStyle: TextStyle(
                    color: Styles().titleColor,
                    fontSize: 16,
                  ),
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: Styles().primaryColor.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: widget.validator,
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, color: Styles().primaryColor.withOpacity(0.5)),
                onPressed: () {
                  widget.controller.clear();
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }
}
