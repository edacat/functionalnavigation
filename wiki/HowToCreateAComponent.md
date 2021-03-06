### Introduction ###

This page will help you create a component that will seamlessly integrate with our trajectory optimization framework. There are many ways to represent system dynamics, trajectory measures, and optimization methods. Therefore, we primarily focus on providing clear interface definitions and leave implementation to the developers of individual components.

### Interface Control Document ###

General coding guidelines for all components including those that are hosted externally:
  * RULE: Component names and classes must be capitalized in `UpperCamelCase` (ex. `MyClass`), and other variables should use `lowerCamelCase` (ex. myVariable).
  * RULE: All implementation files for a component must be grouped within a single directory prefixed by a "+" sign (ex. `+MyComponent`).
  * RULE: The component directory must contain either a MATLAB or C++ class definition file with the same name as the component (ex. `+MyComponent/MyComponent.m` or `+MyComponent/MyComponent.cpp`).
  * RULE: Users should only be expected to modify at most one configuration file. It should have the same name as the component appended by "Config" (ex. `+MyComponent/MyComponentConfig.m` or `+MyComponent/MyComponentConfig.cpp`).
  * RULE: Components should not assume that they are in the ./components directory.
  * RULE: Framework interface bugs should be submitted to the Google Code issue tracker.
  * RULE: All components should offer a silent (non-verbose) mode that prints nothing to the console.

Additional coding guidelines for all code hosted in this repository:
  * RULE: Only upload plain text, C++, or MATLAB files (`makefile, .c, .cpp, .h, .m, .txt`)
  * RULE: Do not upload binaries (`.jpg, .png, .dll, .lib, .mexglx, .mexw32, .vc, .icc., pl, .w32`)
  * RULE: Bugs should be noted using `TODO` statements within code or posted using the online Issue Tracker.
  * RULE: Use two spaces for each indentation level.
  * RULE: At least one blank line should separate functions in files that define multiple functions.
  * RULE: Use no more than 120 characters per line.
  * RULE: Place constants in configuration files or headers whenever possible.
  * RULE: Avoid using global variables.

  * RULE (MATLAB): Code must pass the `mlint` test or contain a comment at each line explaining why not.
  * RULE (MATLAB): Use `fprintf()` instead of `disp()` or `warning()` to print diagnostic information.

  * RULE (C++): Code must compile using "`g++ -ansi -pedantic -Wall -Werror`"
  * RULE (C++): Manage memory through self-contained structures or objects that keep track of their own allocation sizes.
  * RULE (C++): Use EclipseCDTFormatter.xml to format code before submission.

  * RULE: Place a description above each function that identifies input and output parameters (using dOxygen syntax in C++) and has a NOTE section when applicable.
```
// Description of C++ function
//
// @param[in]     aa description of input argument and units
// @param[in,out] bb description of input/output argument and units
// @return           description of return value and units
//
// @note
// Here is extra information.
```
```
% Description of MATLAB function.
%
% INPUT
% aa = description of input and units
% bb = description of another input and units
%
% OUTPUT
% cc = description of output and units
%
% NOTE
% Here is extra information.
```
  * RULE (C++): Use long descriptive variable names or very short ones coupled with detailed descriptions.
```
int triangleVertices = 3;
int a; // index of the first vertex
int b; // second vertex
int c; // third vertex
```
  * RULE (C++): Functions without meaningful return value should be declared void and explicitly return.
```
void function(int a, int b, int *c)
{
  *c=a+b;
  return;
}
```
  * RULE (C++): Prefer one variable declaration per line.
```
int i;
int j;
int k;
```
  * RULE (C++): Whenever possible, initialize variables when they are declared.
```
int a = 0;
double **matrix = NULL;
double point[2] = {0,0};
```

External references for good coding practices and tips:
  * [MATLAB design guidelines](http://www.datatool.com/downloads/matlab_style_guidelines.pdf).
  * [C++ design guidelines](http://www-personal.acfr.usyd.edu.au/tbailey/seminars/design.pdf).

Information on how to wrap code written in different languages:
  * [How to call C++ from Python](http://docs.python.org/extending/extending.html)
  * [How to call Python from C++](http://docs.python.org/extending/embedding.html)
  * [How to call C++ from MATLAB](http://www.mathworks.com/support/tech-notes/1600/1605.html)

### Class Diagram ###

<img src='https://github.com/dddvision/functionalnavigation/blob/master/wiki/SimpleClassDiagram.png'>

<h3>Class Diagram Notation (from Design Patterns)</h3>

<img src='https://github.com/dddvision/functionalnavigation/blob/master/wiki/classDiagramNotation.png'>
