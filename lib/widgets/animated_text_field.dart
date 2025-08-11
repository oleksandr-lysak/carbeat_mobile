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
          color: Styles().backgroundFormColor,
          borderRadius: BorderRadius.circular(Styles.borderRadius),
          border: Border.all(
            color: _isFocused
                ? Styles().primaryColor
                : Styles.subtitleColor,
            width: 1.5,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Styles().primaryColor.withOpacity(0.10),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                maxLines: widget.maxLines,
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                obscureText: widget.isPasswordField,
                cursorColor: Styles().primaryColor,
                //style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  
                  labelText: widget.labelText,
                  labelStyle: TextStyle(
                    color: Styles().primaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                  hintText: widget.hintText,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w300,
                  ),
                  border: InputBorder.none,
                  
                ),
                validator: widget.validator,
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Styles.textInputColor),
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
