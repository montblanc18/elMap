#概要
天体の座標を入力すると、その日のelevation mapを描画する。  
同時に、その日の太陽のelevation mapも表示する。

#使い方
```bash
$ ruby elMap.rb -r <天体のra> -d <天体のdec>
$ ruby elMap.rb -h  
Usage: elMap [options]  
    -r, --ra X                       Right Accension [deg]  
    -d, --dec X                      Declination [deg]  
    -t, --time X                     date of observation JST [pleas don't use]  
```