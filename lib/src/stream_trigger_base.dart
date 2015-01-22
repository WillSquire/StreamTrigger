// Copyright (c) 2015, Will Squire. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library stream_trigger.base;

import 'dart:async';
import 'matcher.dart';

typedef Object TriggerHandle();

class StreamTrigger<S,T> implements StreamTransformer<S,T>
{
  //-------------------------------------------------------------------------------------------
  // Variables - Public
  //-------------------------------------------------------------------------------------------

  Map<List<int>,Object> get triggerMap => _triggerMap;

  //-------------------------------------------------------------------------------------------
  // Variables - Private
  //-------------------------------------------------------------------------------------------

  // Stream
  StreamController _controller;
  StreamSubscription _subscription;
  StreamSubscription _triggeredSubscription;
  Stream<S> _stream;
  List<Stream<S>> _triggeredStreamQueue = new List<Stream<S>>();
  bool cancelOnError; // << Make private?

  // Transform
  Map _triggerMap;
  List<List<int>> _sequences;
  List<Matcher> _matching = new List<Matcher>();
  List<Matcher> _matched = new List<Matcher>();
  List<int> _buffer = new List<int>(); // stores data here until it either is or is not known not to be a command
  List<int> _output = new List<int>();

  //-------------------------------------------------------------------------------------------
  // Functions - Constructor
  //-------------------------------------------------------------------------------------------

  /**
   * Pattern Trigger
   */
  StreamTrigger(Map<Object,TriggerHandle> this._triggerMap, {bool sync: false, bool this.cancelOnError})
  {
    _controller = new StreamController<T>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: ()
        {
          if (_subscription != null)
            _subscription.pause();

          if (_triggeredSubscription != null)
            _triggeredSubscription.pause();
        },
        onResume: ()
        {
          if (_subscription != null)
            _subscription.resume();

          if (_triggeredSubscription != null)
            _triggeredSubscription.resume();
        },
        sync: sync
    );
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Pattern Trigger (Broadcast stream)
   */
  StreamTrigger.broadcast(Map<Object,TriggerHandle> this._triggerMap, {bool sync: false, bool this.cancelOnError})
  {
    _controller = new StreamController<T>.broadcast(
        onListen: _onListen,
        onCancel: _onCancel,
        sync: sync
    );
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Public
  //-------------------------------------------------------------------------------------------

  /**
   * Replace triggers
   *
   * Replaces all currently set triggers to those in the new trigger map.
   * This removes all triggers that are in the process of matching and
   * leaves those that are already matched.
   */
  void setTriggers(Map<List,TriggerHandle> triggers)
  {
    /*
    String x;
    triggers.forEach((v, _)
    {
      x = "'" + UTF8.decode(v) + "' ";
    });
    print("Set triggers = " + x);
    */

    _triggerMap = triggers;
    _setSequences(triggers);
    _matching.clear();
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Private
  //-------------------------------------------------------------------------------------------

  /**
   * _addSequences
   *
   * Adds new sequences for pattern matching.
   */
  void _setSequences(Map<Object,TriggerHandle> triggers)
  {
    _sequences = new List<List<int>>();

    triggers.forEach((List<int> key, _)
    {
      _sequences.add(key);
    });
  }

  //-------------------------------------------------------------------------------------------

  /**
   * On listen
   *
   * Upon listening to this stream transformer, subscribes to default stream.
   */
  void _onListen()
  {
    _sequences = new List<List<int>>();
    _setSequences(_triggerMap);

    _subscription = _stream.listen
    (
        _onData,
        onError: _controller.addError,
        onDone: ()
        {
          _subscription = null;
          _flushBuffer();
          _flushOutput();
          if (_triggeredSubscription == null)
            _controller.close();
        },
        cancelOnError: cancelOnError
    );
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Trigger Subscription
   *
   * Subscribes to a new triggered subscription. On finishing, it checks the
   * triggered stream queue for queued streams to subscribe to next, else it
   * reverts back to the default stream.
   */
  void _triggerSubscription(Stream<S> stream)
  {
    _triggeredSubscription = stream.listen
    (
        _controller.add,
        onError: _controller.addError,
        onDone: ()
        {
          if (_triggeredStreamQueue.isNotEmpty)
          {
            _triggerSubscription(_triggeredStreamQueue.first);
            _triggeredStreamQueue.removeAt(0);
          }
          else
          {
            _triggeredSubscription = null;

            if (_subscription != null)
              _subscription.resume();
            else
              _controller.close();
          }
        },
        cancelOnError: cancelOnError
    );
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Cancel
   *
   * On stream cancel, cancel all subscriptions to streams.
   */
  void _onCancel()
  {
    if (_subscription != null)
      _subscription.cancel();

    if (_triggeredSubscription != null)
      _triggeredSubscription.cancel();
  }

  //-------------------------------------------------------------------------------------------

  /**
   * On data
   *
   * Apply data transformations.
   */
  void _onData(Object data)
  {
    // If data is of array type
    if (data is Iterable)
    {
      data.forEach((Object element)
      {
        _process(element);
      });
    }
    else
      _process(data);

    _flushOutput();
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Bind
   */
  Stream<T> bind(Stream<S> stream)
  {
    this._stream = stream;
    return _controller.stream;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Process
   *
   * If completely matched, this is where it gets interesting.
   * Variables could contain the same sequence as other sequences
   * with more characters in. Need to hold off if there is more
   * than one matching sequence until either the longer sequence
   * (which started before or at the same time) fails or succeeds.
   */
  void _process(Object element)
  {
    _buffer.add(element);
    //print(UTF8.decode([element]));

    // Update matchers
    _updateMatched();
    _updateMatching(element);
    _startMatchers(element);

    if (_matched.isNotEmpty)
    {
      _removeMatchedOverlaps();

      /*
      String x = "";
      _matched.forEach((match)
      {
        x += " '" + UTF8.decode(match.sequence) + "'";
      });
      print("Matched triggers" + x);
      */

      int i = 0;
      while (i < _matched.length)
      {
        if (!_isMatchContested(_matched[i]))
        {
          _removePreviousMatchings(_matched[i]);
          _trigger(_matched[i]);
          _matched.removeAt(i);
        }
        else
        {
          // Only increase index if match is not removed from array (else
          // it will skip the next item)
          i++;
        }
      }
    }
    // Else flush the buffer and add to the output
    else if (_matching.isEmpty)
    {
      _flushBuffer();
    }
  }
  //-------------------------------------------------------------------------------------------

  /**
   * _startMatch
   *
   * Starts matching against the sequence an element matches the start
   * of the sequence. Why do this every time? Think of the variable
   * name 'nank', searched in the string 'nnanank', inject is compatible
   * with and without prefixes and suffixes so it needs to recognise this.
   * Also checks if sequence is complete (in case the sequence is only one
   * element)
   */
  void _startMatchers(int element)
  {
    _sequences.forEach((List<int> trigger)
    {
      if (element == trigger[0])
      {
        //List x = [element];
        //print("Starting match of '" + UTF8.decode(trigger) + "' with element '" + UTF8.decode(x) + "'");
        _matching.add(new Matcher(trigger, 1));

        // Checks if sequence is complete, if yes don't add to array, if not
        // then add to _matchArray be checked again in the next element input
        _sequenceMatch(_matching.last);
      }
    });
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Sequence match
   *
   * Check if any matchers have completed the sequence. If so, move
   * them to the matched List.
   */
  bool _sequenceMatch(Matcher match)
  {
    if (match.isSequenceMatched)
    {
      _matched.add(match);
      _matching.remove(match);

      return true;
    }

    return false;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Update matched
   *
   * As the trigger is already matched, this keeps count of elements
   * added after a sequence is matched. This is to make sure the
   * position of the matched data is accurate in the stream buffer.
   */
  void _updateMatched()
  {
    if (_matched.isNotEmpty)
    {
      _matched.forEach((Matcher matcher)
      {
        matcher.addElementAfterEnd();
      });
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Update matching
   *
   * Check if those that have started matching have matched the new
   * element, if they have completed matching, or if they have failed.
   */
  void _updateMatching(int element)
  {
    int i = 0;
    while (i < _matching.length)
    {
      // Match sequence element
      if (_matching[i].matchElement(element))
      {
        // Check if completed sequence
        if (!_sequenceMatch(_matching[i]))
          // If not removed from array, increase index
          i++;
      }
      else
        // Failed sequencing
        _matching.removeAt(i);
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Match contested
   *
   * If a partially matched sequence started matching before or at the same
   * time as the fully matched. Return contested, as the partially matched
   * sequence might complete (for example, a partially matched sequence
   * might contain the same, or equally matched sequence inside of it. This
   * would mean the longer sequence could be triggered instead)
   */
  bool _isMatchContested(Matcher matched)
  {
    bool contested = false;

    if (_matching.isNotEmpty)
    {
      _matching.forEach((Matcher matching)
      {
        // If matching (partially matched) started at the same time or before,
        // this is contested, as the partial match is of equal size or longer
        // and could return as matched later

        //print("Matching '" + UTF8.decode(matching.sequence) + "'");

        if(matching.elementsToStart >= matched.elementsToStart)
        {
          //print(UTF8.decode(matched.sequence) + " contested by: " + UTF8.decode(matching.sequence));
          contested = true;
        }
      });
    }

    return contested;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Remove matched overlaps
   *
   * Removes overlapping matches on the data stream, prioritising
   * those that start before or at the same time, and end after
   * or at the same time as another. This will still also remove
   * those that start and end at the same time.
   */
  void _removeMatchedOverlaps()
  {
    int i = 0;
    while (i < _matched.length)
    {
      Matcher x = _matched[i];

      int ii = 0;
      while (ii < _matched.length)
      {
        Matcher y = _matched[ii];

        // To prevent from removing itself
        if (x == y)
        {
          ii++;
          continue;
        }

        // If x starts before or at the same time as y
        if(x.elementsToStart >= y.elementsToStart)
        {
          // If x ends after or at the same time as y ends
          if(x.elementsToEnd <= y.elementsToEnd)
          {
            //print("REMOVING: " + UTF8.decode(y.sequence) + " Start: " + y.elementsToStart.toString() + " End: " + y.elementsToEnd.toString());
            _matched.remove(y);
            continue; // WILL IT SKIP OTHERWISE?
          }
        }

        //print("Matched length = " + _matched.length.toString());
        //print(ii);

        ii++;
      }

      i++;
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Remove previous matchings
   *
   * Remove matching (partially matched) starting before
   * matched
   */
  void _removePreviousMatchings(Matcher matched)
  {
    int i = 0;
    while (i < _matching.length)
    {
      if (_matching[i].elementsToStart > matched.elementsToEnd)
        _matching.removeAt(i);
      else
        // Only increase index if match is not removed from array (else
        // it will skip the next item)
        i++;
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Trigger
   *
   * Removes the trigger in the stream, then invokes the trigger's corresponding
   * handler, which also returns data to be given in its place. This also
   * removes any previous buffered elements before the trigger on the stream.
   * Note that triggers invoke handlers, so the _triggerMap is expected to
   * contain triggers as the keys and functions as the values. If trigger handles
   * for matched triggers are removed, it will default to flushing trigger.
   */
  void _trigger(Matcher match)
  {
    //print("Trigger '" + UTF8.decode(match.sequence) + "'");
    //print("Injection Start: " + (_buffer.length - match.elementsToStart).toString() + " End: " + (_buffer.length - match.elementsToEnd).toString());
    //print("Buffer '" + UTF8.decode(_buffer) + "'");

    _flushBuffer(_buffer.length - match.elementsToStart);
    _buffer.removeRange(_buffer.length - match.elementsToStart, _buffer.length - match.elementsToEnd); // 0 based, so length -1
    _flushOutput();

    /*
    _triggerMap.forEach((k, v)
    {
      print(UTF8.decode(match.sequence) + " avalible values = '" + UTF8.decode(k) + "'");
    });
    */

    if (_triggerMap[match.sequence] != null)
    {
      // If the trigger handler is present
      Object triggerResult = _triggerMap[match.sequence]();

      if (triggerResult != null)
      {
        if (triggerResult is Stream<S>)
          _addTriggeredStream(triggerResult);
        else //if (triggerResult is Iterable)
          _output.addAll(triggerResult);
        /*
        else
          _output.add(triggerResult);
         */
      }
    }
    else
      // Else the handle has been removed, and trigger is simply flushed
      _output.addAll(match.sequence);
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Add stream
   *
   * Adds stream to queue if subscriptions are greater than one (i.e. it
   * is subscribed to the original stream plus another). Else it invokes subscription
   * to stream straight away.
   */
  void _addTriggeredStream(Stream<S> stream)
  {
    if (_triggeredSubscription != null)
      _triggeredStreamQueue.add(stream);
    else
    {
      // Pause default stream and subscribe to triggered stream
      _subscription.pause();
      _triggerSubscription(stream);
    }
  }


  //-------------------------------------------------------------------------------------------

  /**
   * Flush buffer
   *
   * Flushes the buffer to the output. Can optionally state how many
   * elements should be flushed from buffer, else the the entire buffer
   * is flushed.
   */
  void _flushBuffer([int amount = null])
  {
    if (amount != null)
    {
      for (int i = 0; i < amount; i++)
      {
        _output.add(_buffer.first);
        _buffer.removeAt(0);
      }
    }
    else
    {
      if (_buffer.length > 0)
      {
        _output.addAll(_buffer);
        _buffer.clear();
      }
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Need to put _output to a new List, due to the fact that if it is
   * cleared after adding it to the stream controller, it sends the
   * cleared List, still relating to the same object
   */
  void _flushOutput()
  {
    if (_triggeredSubscription == null)
    {
      List<int> flushOut = new List.from(_output);
      _output.clear();
      _controller.add(flushOut);
    }
  }
}