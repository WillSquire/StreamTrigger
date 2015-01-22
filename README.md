# stream_trigger

The Stream Trigger object does exactly what the name implies. 
Stream Trigger can be used to either 'trigger' transformations to 
particular data on data streams, or trigger logic to happen 
elsewhere, or both.

It works by spotting the supplied trigger data on a data 
stream, that once spotted, will trigger the corresponding 
'handler' function supplied with it to be invoked. The handler 
function then has the option of replacing the trigger 
data found on the data stream, or leaving it be. 

To replace the trigger data on the stream, the trigger's given 
handler can either return data of the same type as the stream, or 
can return a stream itself of equal typing. Stream Triggers can 
inject/merge one data stream into another at these specific trigger 
points if so desired.

Again, the replacement of the trigger data does not have to occur.
So if this is not desired, returning a null object from the handler
will indicate the data should not change. But please note, the 
handler must have a return.

## Usage

First things first, install and then import the Stream Trigger 
package into your your project. Next define your triggers and 
handlers in a Map object and instantiate the Stream Trigger with 
this (or do both at the same time, as shown in the second example).

As the Stream Trigger object derives from the Stream Transformer 
type, the `transform()` function is needed to bind it to the data 
stream. And that's it, after that it's all set up. Just listen to
the stream.

This first example is the more long and drawn out illustration of 
usage, but this should hopefully articulate it's working better. 
In this example, the trigger data on the stream will be replaced 
by the given data.

```dart

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
}

```

This next example injects/merges one stream into another when the
trigger is found on the stream. It's also more of a shorthand way 
of creating the Stream Trigger object.

```dart
    
import 'package:stream_trigger/stream_trigger.dart';
import 'dart:convert';
import 'dart:io';

main() {
    // A shorter way you might write a Stream Trigger is like 
    // so
    StreamTrigger triggerWithStreamInjection = new StreamTrigger({
        UTF8.encode("injectStreamHere") : () {
          // Note, a stream of the same type can also be returned 
          // here to merge one stream into another, like so.
          return new File(new Uri.file('../README.md')
            .toFilePath())
            .openRead();
        }
    });
    
    // Usage on a stream
    new File(new Uri.file('../LICENSE').toFilePath())
        .openRead()
        .transform(triggerWithStreamInjection)
        .transform(UTF8.decoder)
        .listen((String char) {
          // And get the transformed data here... etc
          print(char);
        });
}
    
```

## Features and bugs

Stream Trigger currently works with the `List<int>` type only, so 
will work with reading raw UTF data, such as information from 
files. It isn't too much work to change this, so will support 
all types (array and non array types) very, very shortly. The aim it 
to support any type of data stream.

Please email myself feature requests and bugs, or find me on 
[twitter][Twitter]. It's lovely to hear any kinda of feedback, so
feel free to contact me whenever.

[Twitter]: https://twitter.com/WillSquire