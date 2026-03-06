
![[Pasted image 20260306160524.png]]



A **toon shader** is a non-photorealistic rendering technique designed to make graphics appear flat and cartoon-like. This effect is achieved by using fewer shading colors instead of smooth gradients, giving the image a stylized, hand-drawn look similar to comic books or traditional 2D animation.

  

### Toon shader steps:

1. calculate the [luminance](https://shader-learning.com/module-training/7/task/49) of each pixel.
2. apply the [Sobel edge-detection filter](https://shader-learning.com/module-training/7/task/176) and get a magnitude.
3. if magnitude > **threshold**, color the pixel black
4. else, quantize the pixel's color.
5. output the colored pixel.

### Color Quantization

  

Color quantization is a process used in image processing to reduce the number of distinct colors in an image. Usually, 32 bits are allocated for the color of an RGBA pixel, meaning each color channel is given 8 bits or 256 values. To reduce the number of values in each channel to **Q** values, you need to:

1. Normalize the channel values to the interval [0.0, 1.0]. Usually, in shader programs, all colors are already normalized, so this step can be skipped.
2. Multiply each channel value by **Q**, round to the nearest integer, and divide back by **Q**.