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
          color: Theme.of(context).hoverColor,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).hoverColor
                : Theme.of(context).hoverColor,
            width: 1.5,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: DropdownButtonFormField<DropdownItem>(
          validator: widget.validator,
          style: Theme.of(context).textTheme.titleMedium,
          value: widget.selectedItem,
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(
              color: _isFocused
                  ? Styles().primaryColor
                  : Styles().primaryColor,
              fontWeight: FontWeight.w400,
            ),
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Styles().primaryColor,
              fontWeight: FontWeight.w300,
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide.none,
            ),
            border: InputBorder.none,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: _isFocused
                ? Styles().primaryColor
                : Styles.descriptionColor,
          ),
          items: widget.items
              .map((item) => DropdownMenuItem<DropdownItem>(
                    value: item,
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: Styles.textInputColor,
                        fontWeight: FontWeight.w400,
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
          dropdownColor: Styles().backgroundFormColor,
          itemHeight: 48.0, // Висота кожного елемента меню
        ),
      ),
    );
  }
}
