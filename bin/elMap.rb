#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
##################
# 手元でELmapを作成するためのscript。
# 汎用性を高めるために、ROOTではなくgnuplotを使う。
#
#####構想#####
# 引数として、radecをとる。
# radecと当日の時刻から該当日の各時刻におけるELを計算する。
# 横軸を時刻、縦軸をELとしてMappingする。
#
# 時刻はJSTを採用する。
# ELはdegreeを採用する。
#
#####################
# 更新履歴
#####################
# YYMMDD ver. author  contents
# XXXXXX 1.0  hikaru  初版
# 141129 1.1  hikaru  引数の処理をブロックで処理するように変更。指定した場所で観測可能なElevation下限値を表示するように修正
##################

require "matrix"
require "gnuplot"
require "time"
require "optparse"

MonthToDay=[0,31,59,90,120,151,181,212,243,273,304,334]

######################
## 各種関数
######################

=begin #もう使わない。
def ReadOpt()
  if 2 > ARGV.length then
    print("[ERROR]\n")
    exit()
  end
  
  for i in 1..((ARGV.length.to_f-2)/2)
    index = 2*i
    if "-t"==ARGV[index].to_s or "--time"==ARGV[index].to_s then
      $setTimeJST=Time.local(ARGV[index+1].to_s.split("/")[0].to_i,
                             ARGV[index+1].to_s.split("/")[1].to_i,
                             ARGV[index+1].to_s.split("/")[2].to_i,
                             10,
                             0)
      print("[OK]You choose ",$setTimeJST,"\n")
    else
      print("[ERROR]\n")
      exit()
    end
  end  
end
=end

def DegToRad(deg)
  rad = deg.to_f*2*Math::PI/360.0
  return rad
end

def RadToDeg(rad)
  deg = rad.to_f*360.to_f/2.to_f/Math::PI
  return deg
end

#与えた時刻に対するELを計算して返す。
def ObsEL(day,ra,dec)
  decc= 2*Math::PI/360.to_f*ObsLat#観測所の北緯を35で仮定。
  raa = 2*Math::PI*((MonthToDay[((day.month).to_i-1)] + day.day-82)).to_f/365.0 #82は年始から3/23までの日数
  #更に何度回転しているか、太陽が正午に南中すると仮定して考える。
  raa = raa + 2*Math::PI*((day.hour - 12)*15 + day.min*0.25)/360.to_f
  #decc
  #el = DEC+Math::PI/2-DegToRad(ObsLat)
  #法線ベクトルとのなす角を取って、90度から引く。
  akeVec=Vector[Math.sin(Math::PI/2-decc)*Math.cos(raa),Math.sin(Math::PI/2-decc)*Math.sin(raa),Math.cos(Math::PI/2-decc)]
  objVec=Vector[Math.sin(Math::PI/2-dec)*Math.cos(ra),Math.sin(Math::PI/2-dec)*Math.sin(ra),Math.cos(Math::PI/2-dec)]
  #p akeVec,objVec,akeVec.inner_product(objVec)
  costheta = akeVec.inner_product(objVec)/(akeVec.r*objVec.r)
  el = sprintf("%0.8f",90-RadToDeg(Math.acos(costheta)))
  return el
end


def SunSetting(day)
  #太陽の座標はraa,decc
  raa = 2*Math::PI*((MonthToDay[((day.month).to_i-1)] + day.day-82)).to_f/365.0
  sunDec = 23.5*Math::PI/180.0
  #decc = 0
  if raa%180 ==0 &&  raa%90 == 0 then
    decc = 0
  end
  if raa%180 !=0 && raa%90 == 0 && raa%270 != 0 then
    decc = 23.5
  end
  if raa%180 !=0 && raa%90 == 0 && raa%270 == 0 then
    decc = -23.5
  end
  if raa%180 !=0 && raa%90 != 0 then
    dir1 = Vector[1/Math.tan(raa),1,Math.tan(sunDec)]
    dir2 = Vector[1/Math.tan(raa),1,0]
    decc = Math.acos((dir1.inner_product(dir2)).to_f/(dir1.r*dir2.r).to_f)
    #deccが必ず正になる。ので注意。下で補正。
    if raa > Math::PI or raa < 0 then 
      decc = -decc
    end
  end
  $SunRa=raa
  $SunDec=decc
end

def CalcEL(day,ra,dec)
  
  for hour in 0..23
    for minute in 0..59
      time=Time.local(day.year,day.mon,day.mday,hour,minute)
      #UTの取得
      hhour=hour-9
      if hhour < 0 then
        dday=day.mday-1
        hhour=hour+24-9
        if dday==0 then #面倒なのでこれで処理
          dday=1
        end
      else
        dday = day.mday
      end
      uttime=Time.gm(day.year,day.mon,dday,hhour,minute)
      $daytime << uttime.hour+uttime.min.to_f/60.to_f
#      p time
      $eldegree << ObsEL(time,ra,dec)
      $sundegree << ObsEL(time,$SunRa,$SunDec)
      $akenoLowerLimit << ObsLowerLimit
    end
  end
end

def MkGnuplot(ra,dec)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      str=sprintf("Elevation Map (%.2f deg, %.2f deg)",ra,dec)
#      str=sprintf("Elevation Map (%.2f,%.2f)",RA,DEC)
      plot.set "terminal x11"
      plot.title str
      plot.ylabel "Elevation[deg]"
      plot.xlabel "UT[hour]"
#      plot.set "log x"
#      plot.set "log y"
      plot.set "xrange [0:24]"
      plot.set "yrange [0:90]"

      plot.data << Gnuplot::DataSet.new([$daytime,$eldegree]) do |ds|
#        ds.with = "lines"
        ds.title = "object"
      end
      plot.data << Gnuplot::DataSet.new([$daytime,$sundegree]) do |ds|
        ds.title = "sun"
      end
      plot.data << Gnuplot::DataSet.new([$daytime,$akenoLowerLimit]) do |ds|
        str = sprintf("Lower Limit: %d deg.",ObsLowerLimit)
        ds.title = str
      end
    end
  end
end

######################
## main文
######################
$daytime=[] #時刻を入力する。
$eldegree=[] #エレベーションを入力する。
$sundegree=[] #太陽のEL
$akenoLowerLimit=[]
opts={}


setTimeJST=Time.now #時刻JSTを取得
setTimeUT=Time.now.gmtime #時刻UTを取得
ObsLat=35.7866 #観測所のLat
ObsLon=138.4806 #観測所のLon
ObsLowerLimit=10 #観測所で観測可能な最低Elevation
ObsRadias=900+6400000 #900m+6400km

if __FILE__==$0
  #ReadOpt()

  ARGV.options do |o|
    o.on("-r X","--ra","Right Accension [deg]"){|x| opts[:ra]=x}
    o.on("-d X","--dec","Declination [deg]"){|x| opts[:dec]=x}
    o.on("-t X","--time","date of observation JST [pleas don't use]"){|x|
      opts[:time]=x
      temp = x.to_s.split("/")
      if 5==temp.len
        setTime=Time.local(temp[0].to_i,temp[1].to_i,temp[2].to_i,10,0)
      else
        print("[Error] You set wrong time.\n")
        exit
      end
    }
    o.parse!
  end
  
  #radecを取得する。
  RA=DegToRad(opts[:ra].to_f)
  DEC=DegToRad(opts[:dec].to_f)
  
  #各時刻におけるELを計算。
  SunSetting(setTimeJST)
  CalcEL(setTimeJST,RA,DEC)
  
  #出力。
  MkGnuplot(opts[:ra],opts[:dec])
  print("Output El Map: ",setTimeJST,"\n")
  print("Obeject Pos.: ",opts[:ra]," ",opts[:dec],"\n")
  print("[SUCCESS]\n")
end
