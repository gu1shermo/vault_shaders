
Assume that the screen size always matches the texture size. Thus, each screen pixel corresponds to one texture pixel:

  

![Texture - Screen](https://whale-app-toyuq.ondigitalocean.app/shader-learning-api/files/image/pixelation-eq-resolution.png)

Texture - Screen

  

To make the texture appear more pixelated on the screen, its resolution should be lower than the screen resolution. This way, one texture pixel will correspond to multiple screen pixels:

  

![Texture - Screen](https://whale-app-toyuq.ondigitalocean.app/shader-learning-api/files/image/pixelation-low-resolution.png)

Texture - Screen

  

We can simulate pixelation by dividing the screen into blocks of size **N**x**N** pixels and assigning each block a single pixel from the texture. For simplicity, we will take the color of the first pixel from each block in the texture and apply it to the entire block on the screen: