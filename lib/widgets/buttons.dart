import 'package:flutter/material.dart';

enum Size { small, medium, large }

class Button extends StatefulWidget {
  final String labelText;
  final void Function()? onPressed;
  final bool active;
  final Size size;
  final IconData icon;

  const Button({
    super.key,
    required this.labelText,
    required this.onPressed,
    required this.active,
    required this.size,
    required this.icon,
  });

  @override
  ButtonState createState() => ButtonState();
}

class ButtonState extends State<Button> {
  @override
  Widget build(BuildContext context) {
    ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      backgroundColor: Theme.of(context).primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 5,
    );
    TextStyle textStyle = Theme.of(context).textTheme.bodyMedium!;
    if (widget.size == Size.small) {
      buttonStyle = buttonStyle.copyWith(
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0)),
      );
      textStyle = Theme.of(context).textTheme.bodySmall!;
    } else if (widget.size == Size.large) {
      buttonStyle = buttonStyle.copyWith(
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0)),
      );
      textStyle = Theme.of(context).textTheme.bodyLarge!;
    }
    return ElevatedButton(
      style: buttonStyle,
      onPressed: widget.onPressed,
      child: Row(
        children: [
          Icon(widget.icon, color: textStyle.color),
          const SizedBox(width: 3.0),
          Text(
            widget.labelText,
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
