import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'white_card.dart';

class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.name,
    required this.planLabel,
    required this.activeUntilEc,
  });

  final String name;
  final String planLabel;
  final String activeUntilEc;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with plan chip
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.blue.shade700.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  planLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Active Until (EC)', activeUntilEc),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 2),
          Text(v, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      );
}
