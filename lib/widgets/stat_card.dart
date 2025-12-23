// Location: lib/widgets/stat_card.dart
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit = '',
    required this.icon,
    required this.bgColor,
    this.iconColor = Colors.blue,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade100, blurRadius: 4, spreadRadius: 1)
          ],
          border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.1) : bgColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : iconColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black)),
                      const SizedBox(width: 4),
                      if (unit.isNotEmpty)
                        Text(unit,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSelected ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}