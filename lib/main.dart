// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:verovio_integration/myIO.dart';
import 'package:verovio_integration/verovio/verovio_method_store.dart';

void doPrintTimesList(List<int> times, String title, int reps, int sets) {
  int sum = times.fold(0, (previousValue, element) => previousValue += element);
  double avg = sum / sets;
  double perItemAvg = avg / reps;
  
  print("");
  print("-----------------------------------------");
  print("Testing results:");
  print("Done $reps times, repeated $sets times");
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

void doLibTests(int reps, int sets) {
  VerovioMethodStore verovio = VerovioMethodStore();
  String content = IOWorker.getFileText("fullPage.mei");
  
  // Test a full-page load and render
  List<int> fullLoadRenderTimes = [];
  for (int i = 0; i < sets; i++) {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    for (int j = 0; j < reps; j++) {
      testLoadAndRenderFull(verovio, content);
    }
    fullLoadRenderTimes.add(DateTime.now().millisecondsSinceEpoch - startTime);
  }
  doPrintTimesList(fullLoadRenderTimes, "Full Load and Render Test (Full Page)", reps, sets);
  
  // Test a full-page load and render
  verovio.loadData(content);
  List<int> onlyRenderTimes = [];
  for (int i = 0; i < sets; i++) {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    for (int j = 0; j < reps; j++) {
      testRenderOnly(verovio);
    }
    onlyRenderTimes.add(DateTime.now().millisecondsSinceEpoch - startTime);
  }
  doPrintTimesList(onlyRenderTimes, "Render Only Tests (Full Page)", reps, sets);
}

void testLoadAndRenderFull(VerovioMethodStore verovio, String content) {
  verovio.loadData(content);
  verovio.getSVGOutput();
}

void testRenderOnly(VerovioMethodStore verovio) {
  verovio.getSVGOutput();
}

void experimentLibFuncs() {
  VerovioMethodStore verovio = VerovioMethodStore();
  String content = IOWorker.getFileText("fullPage.mei");
  verovio.loadData(content);
  
  print("About to edit score");
  // Now try to edit the score
  //verovio.executeEdit("{'action': 'remove', 'param': {'elementId': 'd1e1498'}}");
  //verovio.executeEdit("{'action': 'keyDown', 'param': {'elementId': 'd1e1498', 'key': 1}}");
  //verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e1498'}}");
  print("Done editing score");
}

void main() {
  // doLibTests(5, 5);
  experimentLibFuncs();
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
