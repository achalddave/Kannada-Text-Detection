# Kannada Text Detection

Detecting Kannada in natural scene images.
[Gautam](https://github.com/gautamgunjala/) and I are working on this as our
final project for
[EE225B: Digital Image Processing](https://inst.eecs.berkeley.edu/~ee225b/).

## Goal

This is a modified version of the [Stroke Width Transform][1]. Currently, the
modifications should improve detections on any language, but our goal is to
improve the accuracy with which Kannada text is detected and to decrease the
false positive rate, even at the cost of detecting other languages.

## Implemented modifications

Modifications that we've implemented so far.

### Erosion (morphological)

Morphological erosion is used for two improvements: removal of small non-axis
aligned line-like components, and stroke width variance thresholding.

The original SWT thresholds components using a few metrics, primarily ones
involving their height, width, and stroke width variance. Unfortunately, this
results in a number of diagonal lines and small patches. Eroding the component
and thresholding by the number of pixels fixes this issue.

Second, in natural images, letters are often not perfectly segmented by most
edge detectors (especially for signs in developing countries that are often
carved in stone), which results in components containing small erroneous pixels
outside of letters. The regular stroke width variance thresholding ignores
these due to the extra pixels; to avoid this, we use an erosion to only look at
the variance of the core of the image.

### Multi step thresholding

This is more of an implementation detail, but it's extremely helpful for
performance to threshold in more than one step. We found that the default SWT
provided millions of extremely small components (1-2 pixels).  Unfortunately,
the various thresholding methods in this algorithm are difficult to vectorize,
meaning it is necessary to loop over every component. However, we can vectorize
the removal of very small components using typical MATLAB (or any other
languages') functions, reducing the components to thousands before doing
further checks.

## Proposed modifications

### Gradient histograms

Kannada characters are especially circular in nature, a feature that we should
be able to exploit in detection. We attempted to look at a ray histogram of
gradients for each connected component, but found it unstable in our first few
tries.

### Surrounding text voting

Text tends to be surrounded by other text. Using a dual threshold, we can
eliminate components that are obviously incorrect (by some measure), and vote
on components that we are less certain for by looking at their surroundings (a
la the Canny edge detector).

### Color quantization

[Ikica and Peer] [3] discuss a modified color reduction method using SWT
voting. It may be possible to invert this and use color reduction to vote on
SWT components,, but we have not looked into this much.

### Related

* [DetectText] [3] is an SWT implementation in C++, and was invaluable as
  a reference implementation.

[1]: http://research.microsoft.com/pubs/149305/1509.pdf
[2]: http://asp.eurasipjournals.com/content/2013/1/95
[3]: https://github.com/achalddave/Kannada-Text-Detection
