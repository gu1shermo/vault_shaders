![[Pasted image 20260306155535.png]]


Edge detection is a technique used in image processing to identify points in an image where the brightness changes sharply. These points typically correspond to the boundaries of objects within the image. The **Sobel filter** is a popular edge detection method that uses convolution kernels to approximate the gradient of the image intensity.

  
![[Pasted image 20260306155417.png]]


### Gradient

  

The gradient of image intensity refers to how quickly the brightness of the image changes from one pixel to the next.

  

### Convolution Kernel

  

A convolution kernel is a small matrix of numbers. Think of it as a tiny window that you slide over an image to look at small parts of it at a time.

  

![](https://whale-app-toyuq.ondigitalocean.app/shader-learning-api/files/image/edge-detection-convolution-kernel.png)

  

For each position, you multiply the numbers in the kernel by the corresponding values in the image, then add up all those products. This gives you a new value for the pixel, which can be used to create effects like blurring, sharpening, or detecting edges.

  

### Sobel filter

  


![[Pasted image 20260306155456.png]]
