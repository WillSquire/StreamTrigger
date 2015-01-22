// Copyright (c) 2015, Will Squire. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library stream_trigger.example;

import 'package:stream_trigger/stream_trigger.dart';
import 'dart:convert';
import 'dart:io';

main() {
  // This will be our trigger in the stream, the string
  // "<your name>" is encoded in UTF format (List<int> type)
  List<int> utfEncodedString = UTF8.encode("<your name>");

  // Stream Trigger requires a Map object to be supplied,
  // where the maps' keys are the 'triggers' and values are
  // the 'handlers'. (Note, handlers MUST be a function with
  // a return value)
  Map<List<int>,TriggerHandle> triggerHandles = new Map<List<int>,TriggerHandle>();

  triggerHandles[utfEncodedString] = () {
    // Stuff here will be executed when the trigger (which
    // in this case is '<your name>', in a UTF encoded
    // format) occurs in sequence on the stream.
    print("Trigger has invoked handler");

    // This function MUST return what element/s replace the
    // trigger on the stream, if no change is to occur to
    // the trigger element/s, return null. Else return what
    // will replace the trigger on the stream. (Note,
    // other stream objects can also be returned by the
    // handler to 'inject' one stream into another.
    return UTF8.encode("Will Squire");
  };

  // Stream Trigger requires the trigger/handler map on
  // instantiation.
  StreamTrigger streamTrigger = new StreamTrigger(triggerHandles);

  // Next a stream is needed to apply the Stream Trigger
  // to. The Stream Trigger is a type of Stream Transformer
  // and is fed into the .transform() function like so.
  // (Note, '../LICENSE' might not be a valid location on
  // your system, change as needed).
  new File(new Uri.file('../LICENSE').toFilePath())
    .openRead()
    .transform(streamTrigger)
    .transform(UTF8.decoder)
    .listen((String char) {
      // Stream with Stream Trigger alterations taking place,
      // which in the given example, will replace any
      // occurrences of '<your name>' with 'Will Squire'.
      // (Note that no alterations need to be made to the
      // stream, it could simply return null and carry out
      // other operations).
      print(char);
    });

  // A shorter way you might write a Stream Trigger is like 
  // so
  StreamTrigger triggerWithStreamInjection = new StreamTrigger({
    UTF8.encode("A library useful for applications or for sharing on pub.dartlang.org.") : () {
      // Note, a stream of the same type can also be returned 
      // here to merge one stream into another, like so.
      return new File(new Uri.file('../README.md')
        .toFilePath())
        .openRead();
    }
  });
  
  new File(new Uri.file('../pubspec.yaml').toFilePath())
    .openRead()
    .transform(triggerWithStreamInjection)
    .transform(UTF8.decoder)
    .listen((String char) {
      // And get the data here... etc
      print(char);
    });
}