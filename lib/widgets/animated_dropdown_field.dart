import 'package:flutter/material.dart';
import 'package:carbeat/constants/styles.dart';

class DropdownItem {
  final int id;
  final String name;

  DropdownItem({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropdownItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AnimatedDropdownField extends StatefulWidget {
  final String labelText;
  final String? hintText;
  final List<DropdownItem> items;
  final DropdownItem? selectedItem;
  final ValueChanged<DropdownItem?>? onChanged;
  final String? Function(DropdownItem?)? validator;

  const AnimatedDropdownField({
    super.key,
    required this.labelText,
    this.hintText,
    required this.items,
    this.selectedItem,
    this.onChanged,
    this.validator,
  });

  @override
  AnimatedDropdownFieldState createState() => AnimatedDropdownFieldState();
}

class AnimatedDropdownFieldState extends State<AnimatedDropdownField> {
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
            color:
                Styles().titleColor.withOpacity(0.5),
            width: 0.7,
          ),
        ),
        child: DropdownButtonFormField<DropdownItem>(
          validator: widget.validator,
          style: TextStyle(
            color: Styles().primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          value: widget.selectedItem,
          decoration: InputDecoration(
            fillColor: Styles().primaryColor,
            labelText: widget.labelText,
            labelStyle: TextStyle(
              color: Styles().primaryColor.withOpacity(0.5),
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
          icon: Icon(
            Icons.arrow_drop_down,
            color: Styles().primaryColor.withOpacity(0.5),
          ),
          items: widget.items
              .map((item) => DropdownMenuItem<DropdownItem>(
                    value: item,
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: Styles().titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (DropdownItem? value) {
            setState(() {
              // Оновлюємо вибраний елемент
            });
            if (widget.onChanged != null) {
              widget.onChanged!(value);
            }
          },
          dropdownColor: Styles().primaryColor,
          itemHeight: 48.0, // Висота кожного елемента меню
        ),
      ),
    );
  }
}
