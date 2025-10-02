import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A simple key–value row
Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: GoogleFonts.poppins()),
          Expanded(
            child: Text(
              b,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

/// A bold style row
Widget rowBold(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            a,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              b,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

/// A colored row for highlights (red, orange, green, etc.)
Widget rowColored(String a, String b, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            a,
            style: GoogleFonts.poppins(color: c),
          ),
          Expanded(
            child: Text(
              b,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.poppins(color: c),
            ),
          ),
        ],
      ),
    );
