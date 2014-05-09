# EE225B (Digital Image Processing) Final Project

Detecting Kannada in natural scene images

## Goal

This is a modified version of the [Stroke Width Transform][1]. Currently, the
modifications should improve detections on any language, but our goal is to
improve the accuracy with which Kannada text is detected and to decrease the
false positive rate, even at the cost of detecting other languages.

## Implemented modifications

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

### Proposed

In progress


[1]: http://research.microsoft.com/pubs/149305/1509.pdf
