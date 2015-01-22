// Copyright (c) 2015, Will Squire. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

class Matcher<T>
{
  //-------------------------------------------------------------------------------------------
  // Variables - Public
  //-------------------------------------------------------------------------------------------

  List<T> get sequence => _sequence;
  int get elementsMatched => _elementsMatched;
  int get elementsToStart => _elementsToStart();
  int get elementsToEnd => _elementsToEnd;
  bool get isSequenceMatched => _sequenceMatched;

  //-------------------------------------------------------------------------------------------
  // Variables - Private
  //-------------------------------------------------------------------------------------------

  List<T> _sequence; // Objects are passed by reference, so this is just a pointer and inexpensive (all using same object, not copying it)
  int _elementsMatched;
  int _elementsToEnd = 0; // sequence can't be unmatched once it's already matched, so offset is added
  bool _sequenceMatched = false;

  //-------------------------------------------------------------------------------------------
  // Functions - Constructor
  //-------------------------------------------------------------------------------------------

  /**
   * _Matcher
   *
   * Instantiate with the sequence to match against and initialise with
   * the amount of elements in the sequence already matched.
   */
  Matcher(List<T> this._sequence, int this._elementsMatched)
  {
    _sequenceMatch();
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Public
  //-------------------------------------------------------------------------------------------

  /**
   * Match element
   *
   * No need to +1 to check next element, as array is 0 based and
   * _elementMatch isn't
   */
  bool matchElement(T element)
  {
    if (_sequence[_elementsMatched] == element)
    {
      _elementsMatched++;
      _sequenceMatch();

      return true;
    }

    return false;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Sequence already completed, remember how many elements ago it did this
   */
  void addElementAfterEnd()
  {
    _elementsToEnd++;
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Private
  //-------------------------------------------------------------------------------------------

  /**
   * _sequenceMatch
   *
   * Compares the count of matching elements against the length of the sequence.
   * If it is as long as the sequence, the sequence has been matched.
   */
  void _sequenceMatch()
  {
    if (_elementsMatched == _sequence.length) _sequenceMatched = true;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * elementsLength
   *
   * Returns the length of elements passed since matcher started.
   * Includes offset, as the matcher be be fully matched, but continue
   * to receive elements, incurring an offset from finish.
   */
  int _elementsToStart()
  {
    return _elementsMatched + _elementsToEnd;
  }
}