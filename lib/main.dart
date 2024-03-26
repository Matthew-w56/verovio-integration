/// Author: Matthew Williams
/// Date:   March 2024

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:verovio_integration/test/verovio_tests.dart';

import 'interaction/hitbox_manager.dart';
import 'myIO.dart';
import 'verovio/verovio_api.dart';

void makeVerovioEngraving() {
  VerovioAPI verovio = VerovioAPI();
  String meiContent = IOWorker.getFileText("Joplin_Maple_leaf_Rag.mei");
  // print(verovio.getOptions());
  verovio.setOptions("""{
    'footer': 'none'
  }""");
  verovio.loadData(meiContent);
  String svgContent = verovio.getSVGOutput(generateXml: true);
  File file = File("assets/svgOutput.svg");
  file.writeAsString(svgContent);
  // Done writing file!
}

void main() {
  //makeVerovioEngraving();
  //doLibTests(50, 50);
  runApp(const MainApp());
  //HitboxManager manager = HitboxManager();
  //manager.initHitboxes(IOWorker.getFileText("svgOutput.svg"));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    HitboxManager manager = HitboxManager();
    String musicSvg = IOWorker.getFileText("svgOutput.svg");
    manager.initHitboxes(musicSvg);
    String hitboxString = manager.drawHitboxes();
    String jointSvg = musicSvg.replaceFirst("</svg>", "") + hitboxString.replaceFirst("<svg viewBox='0 0 21000 29700' width='2100px' height='2970px'>", "");
    
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ScalableImageWidget(
            si: ScalableImage.fromSvgString(jointSvg),
            //si: ScalableImage.fromSvgString(IOWorker.getFileText("svgOutput.svg")),
          )
        ),
      ),
    );
  }
}
