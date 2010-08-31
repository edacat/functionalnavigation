#ifndef WORLDTIME_H
#define WORLDTIME_H

namespace tom
{
  /**
   * This class represents a world time system
   *
   * NOTES
   * The default reference is GPS time at the prime meridian in seconds since 1980 JAN 06 T00:00:00
   * Choosing another time system may adversely affect interoperability between framework classes
   */
  typedef double WorldTime;
}

#endif