// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:verovio_integration/myIO.dart';
import 'package:verovio_integration/verovio/verovio_method_store.dart';

void doPrintTimesList(List<int> times, String title, int reps, int sets) {
  int sum = times.fold(0, (previousValue, element) => previousValue += element);
  double avg = sum / sets;
  double perItemAvg = avg / reps;
  
  print("");
  print("-----------------------------------------");
  print("Testing results from a ${reps}x$sets");
  print("-----------------------------------------");
  print(title);
  print("-----------------------------------------");
  print(times);
  print("Total test run time:\t\t$sum");
  print("Average set time:\t\t$avg");
  print("Average individual time:\t$perItemAvg");
  print("-----------------------------------------");
  print("");
}

void performTest(Function testFunc, int reps, int sets, VerovioMethodStore verovio, String content, String title) {
  List<int> timesList = [];
  for (int i = 0; i < sets; i++) {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    for (int j = 0; j < reps; j++) {
      testFunc(verovio, content);
    }
    timesList.add(DateTime.now().millisecondsSinceEpoch - startTime);
  }
  doPrintTimesList(timesList, title, reps, sets);
}

void doLibTests(int reps, int sets) {
  VerovioMethodStore verovio = VerovioMethodStore();
  String content = IOWorker.getFileText("oneLine.mei");
  
  // print(verovio.getOptions());
  
  performTest(
    testLoadAndRenderFull,
    reps, sets, verovio, content,
    "Stock Load And Render Test"
  );
  
  // Load the data in so that there's something to render
  verovio.loadData(content);
  performTest(
    testRenderOnly,
    reps, sets, verovio, "",
    "Render Only Test"
  );
  
  performTest(
    testEditAndRenderStable,
    reps, sets, verovio, content,
    "Load, Edit, and Render (Stable) Test"
  );
  
  performTest(
    testEditAndRenderUnstable,
    reps, sets, verovio, content,
    "Load, Edit, and Render (UNSTABLE) Test"
  );
}

void testLoadAndRenderFull(VerovioMethodStore verovio, String content) {
  verovio.loadData(content);
  verovio.getSVGOutput();
}

void testRenderOnly(VerovioMethodStore verovio, String _) {
  verovio.getSVGOutput();
}

void testEditAndRenderStable(VerovioMethodStore verovio, String content) {
  verovio.loadData(content);
  verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e966'}}");
  verovio.getSVGOutput();
}

void testEditAndRenderUnstable(VerovioMethodStore verovio, String content) {
  verovio.loadData(content);
  verovio.executeEditExperimental("{'action': 'delete', 'param': {'elementId': 'd1e966'}}");
  String output = verovio.getSVGOutput();
  print(output);
}

void experimentLibFuncs() {
  VerovioMethodStore verovio = VerovioMethodStore();
  String content = IOWorker.getFileText("fullPage.mei");
  verovio.loadData(content);
  verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e966'}}");
  verovio.executeEdit("{'action': 'commit'}");
  print("Page in score: ${verovio.getPageCount()}");
  String svgContent = verovio.getSVGOutput();
  File file = File("C:/Users/mbwil/Desktop/alteredOutput2.svg");
  print("-----------------GOT FILE BUILT");
  file.writeAsString(svgContent);
  
  /*print("About to edit score");
  // Now try to edit the score
  //verovio.executeEdit("{'action': 'remove', 'param': {'elementId': 'd1e966'}}");
  //verovio.executeEdit("{'action': 'keyDown', 'param': {'elementId': 'd1e966', 'key': 1}}");
  verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e966'}}");
  verovio.executeEdit("{'action': 'commit', 'param': {}}");
  print("Done editing score");
  String svgContent = verovio.getSVGOutput();
  print("-----------------SVG BUILT");
  File file = File("C:/Users/mbwil/Desktop/alteredOutput.svg");
  print("-----------------GOT FILE BUILT");
  file.writeAsString(svgContent);*/
}

void main() {
  doLibTests(5, 5);
  // experimentLibFuncs();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
