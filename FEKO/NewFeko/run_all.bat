@echo off
echo ===== FEKO 多点批量仿真 (100 个位置) =====

echo [%date% %time%] 位置 1/100: (0.50, 0.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos1.pre
if %errorlevel% neq 0 echo ERROR at position 1  && pause

echo [%date% %time%] 位置 2/100: (0.50, 1.53, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos2.pre
if %errorlevel% neq 0 echo ERROR at position 2  && pause

echo [%date% %time%] 位置 3/100: (0.50, 4.00, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos3.pre
if %errorlevel% neq 0 echo ERROR at position 3  && pause

echo [%date% %time%] 位置 4/100: (0.50, 6.47, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos4.pre
if %errorlevel% neq 0 echo ERROR at position 4  && pause

echo [%date% %time%] 位置 5/100: (0.50, 7.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos5.pre
if %errorlevel% neq 0 echo ERROR at position 5  && pause

echo [%date% %time%] 位置 6/100: (2.75, 0.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos6.pre
if %errorlevel% neq 0 echo ERROR at position 6  && pause

echo [%date% %time%] 位置 7/100: (2.75, 1.53, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos7.pre
if %errorlevel% neq 0 echo ERROR at position 7  && pause

echo [%date% %time%] 位置 8/100: (2.75, 4.00, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos8.pre
if %errorlevel% neq 0 echo ERROR at position 8  && pause

echo [%date% %time%] 位置 9/100: (2.75, 6.47, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos9.pre
if %errorlevel% neq 0 echo ERROR at position 9  && pause

echo [%date% %time%] 位置 10/100: (2.75, 7.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos10.pre
if %errorlevel% neq 0 echo ERROR at position 10  && pause

echo [%date% %time%] 位置 11/100: (7.25, 0.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos11.pre
if %errorlevel% neq 0 echo ERROR at position 11  && pause

echo [%date% %time%] 位置 12/100: (7.25, 1.53, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos12.pre
if %errorlevel% neq 0 echo ERROR at position 12  && pause

echo [%date% %time%] 位置 13/100: (7.25, 4.00, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos13.pre
if %errorlevel% neq 0 echo ERROR at position 13  && pause

echo [%date% %time%] 位置 14/100: (7.25, 6.47, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos14.pre
if %errorlevel% neq 0 echo ERROR at position 14  && pause

echo [%date% %time%] 位置 15/100: (7.25, 7.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos15.pre
if %errorlevel% neq 0 echo ERROR at position 15  && pause

echo [%date% %time%] 位置 16/100: (9.50, 0.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos16.pre
if %errorlevel% neq 0 echo ERROR at position 16  && pause

echo [%date% %time%] 位置 17/100: (9.50, 1.53, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos17.pre
if %errorlevel% neq 0 echo ERROR at position 17  && pause

echo [%date% %time%] 位置 18/100: (9.50, 4.00, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos18.pre
if %errorlevel% neq 0 echo ERROR at position 18  && pause

echo [%date% %time%] 位置 19/100: (9.50, 6.47, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos19.pre
if %errorlevel% neq 0 echo ERROR at position 19  && pause

echo [%date% %time%] 位置 20/100: (9.50, 7.50, 0.30)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos20.pre
if %errorlevel% neq 0 echo ERROR at position 20  && pause

echo [%date% %time%] 位置 21/100: (0.50, 0.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos21.pre
if %errorlevel% neq 0 echo ERROR at position 21  && pause

echo [%date% %time%] 位置 22/100: (0.50, 1.53, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos22.pre
if %errorlevel% neq 0 echo ERROR at position 22  && pause

echo [%date% %time%] 位置 23/100: (0.50, 4.00, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos23.pre
if %errorlevel% neq 0 echo ERROR at position 23  && pause

echo [%date% %time%] 位置 24/100: (0.50, 6.47, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos24.pre
if %errorlevel% neq 0 echo ERROR at position 24  && pause

echo [%date% %time%] 位置 25/100: (0.50, 7.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos25.pre
if %errorlevel% neq 0 echo ERROR at position 25  && pause

echo [%date% %time%] 位置 26/100: (2.75, 0.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos26.pre
if %errorlevel% neq 0 echo ERROR at position 26  && pause

echo [%date% %time%] 位置 27/100: (2.75, 1.53, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos27.pre
if %errorlevel% neq 0 echo ERROR at position 27  && pause

echo [%date% %time%] 位置 28/100: (2.75, 4.00, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos28.pre
if %errorlevel% neq 0 echo ERROR at position 28  && pause

echo [%date% %time%] 位置 29/100: (2.75, 6.47, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos29.pre
if %errorlevel% neq 0 echo ERROR at position 29  && pause

echo [%date% %time%] 位置 30/100: (2.75, 7.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos30.pre
if %errorlevel% neq 0 echo ERROR at position 30  && pause

echo [%date% %time%] 位置 31/100: (7.25, 0.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos31.pre
if %errorlevel% neq 0 echo ERROR at position 31  && pause

echo [%date% %time%] 位置 32/100: (7.25, 1.53, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos32.pre
if %errorlevel% neq 0 echo ERROR at position 32  && pause

echo [%date% %time%] 位置 33/100: (7.25, 4.00, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos33.pre
if %errorlevel% neq 0 echo ERROR at position 33  && pause

echo [%date% %time%] 位置 34/100: (7.25, 6.47, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos34.pre
if %errorlevel% neq 0 echo ERROR at position 34  && pause

echo [%date% %time%] 位置 35/100: (7.25, 7.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos35.pre
if %errorlevel% neq 0 echo ERROR at position 35  && pause

echo [%date% %time%] 位置 36/100: (9.50, 0.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos36.pre
if %errorlevel% neq 0 echo ERROR at position 36  && pause

echo [%date% %time%] 位置 37/100: (9.50, 1.53, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos37.pre
if %errorlevel% neq 0 echo ERROR at position 37  && pause

echo [%date% %time%] 位置 38/100: (9.50, 4.00, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos38.pre
if %errorlevel% neq 0 echo ERROR at position 38  && pause

echo [%date% %time%] 位置 39/100: (9.50, 6.47, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos39.pre
if %errorlevel% neq 0 echo ERROR at position 39  && pause

echo [%date% %time%] 位置 40/100: (9.50, 7.50, 0.65)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos40.pre
if %errorlevel% neq 0 echo ERROR at position 40  && pause

echo [%date% %time%] 位置 41/100: (0.50, 0.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos41.pre
if %errorlevel% neq 0 echo ERROR at position 41  && pause

echo [%date% %time%] 位置 42/100: (0.50, 1.53, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos42.pre
if %errorlevel% neq 0 echo ERROR at position 42  && pause

echo [%date% %time%] 位置 43/100: (0.50, 4.00, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos43.pre
if %errorlevel% neq 0 echo ERROR at position 43  && pause

echo [%date% %time%] 位置 44/100: (0.50, 6.47, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos44.pre
if %errorlevel% neq 0 echo ERROR at position 44  && pause

echo [%date% %time%] 位置 45/100: (0.50, 7.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos45.pre
if %errorlevel% neq 0 echo ERROR at position 45  && pause

echo [%date% %time%] 位置 46/100: (2.75, 0.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos46.pre
if %errorlevel% neq 0 echo ERROR at position 46  && pause

echo [%date% %time%] 位置 47/100: (2.75, 1.53, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos47.pre
if %errorlevel% neq 0 echo ERROR at position 47  && pause

echo [%date% %time%] 位置 48/100: (2.75, 4.00, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos48.pre
if %errorlevel% neq 0 echo ERROR at position 48  && pause

echo [%date% %time%] 位置 49/100: (2.75, 6.47, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos49.pre
if %errorlevel% neq 0 echo ERROR at position 49  && pause

echo [%date% %time%] 位置 50/100: (2.75, 7.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos50.pre
if %errorlevel% neq 0 echo ERROR at position 50  && pause

echo [%date% %time%] 位置 51/100: (7.25, 0.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos51.pre
if %errorlevel% neq 0 echo ERROR at position 51  && pause

echo [%date% %time%] 位置 52/100: (7.25, 1.53, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos52.pre
if %errorlevel% neq 0 echo ERROR at position 52  && pause

echo [%date% %time%] 位置 53/100: (7.25, 4.00, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos53.pre
if %errorlevel% neq 0 echo ERROR at position 53  && pause

echo [%date% %time%] 位置 54/100: (7.25, 6.47, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos54.pre
if %errorlevel% neq 0 echo ERROR at position 54  && pause

echo [%date% %time%] 位置 55/100: (7.25, 7.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos55.pre
if %errorlevel% neq 0 echo ERROR at position 55  && pause

echo [%date% %time%] 位置 56/100: (9.50, 0.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos56.pre
if %errorlevel% neq 0 echo ERROR at position 56  && pause

echo [%date% %time%] 位置 57/100: (9.50, 1.53, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos57.pre
if %errorlevel% neq 0 echo ERROR at position 57  && pause

echo [%date% %time%] 位置 58/100: (9.50, 4.00, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos58.pre
if %errorlevel% neq 0 echo ERROR at position 58  && pause

echo [%date% %time%] 位置 59/100: (9.50, 6.47, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos59.pre
if %errorlevel% neq 0 echo ERROR at position 59  && pause

echo [%date% %time%] 位置 60/100: (9.50, 7.50, 1.50)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos60.pre
if %errorlevel% neq 0 echo ERROR at position 60  && pause

echo [%date% %time%] 位置 61/100: (0.50, 0.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos61.pre
if %errorlevel% neq 0 echo ERROR at position 61  && pause

echo [%date% %time%] 位置 62/100: (0.50, 1.53, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos62.pre
if %errorlevel% neq 0 echo ERROR at position 62  && pause

echo [%date% %time%] 位置 63/100: (0.50, 4.00, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos63.pre
if %errorlevel% neq 0 echo ERROR at position 63  && pause

echo [%date% %time%] 位置 64/100: (0.50, 6.47, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos64.pre
if %errorlevel% neq 0 echo ERROR at position 64  && pause

echo [%date% %time%] 位置 65/100: (0.50, 7.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos65.pre
if %errorlevel% neq 0 echo ERROR at position 65  && pause

echo [%date% %time%] 位置 66/100: (2.75, 0.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos66.pre
if %errorlevel% neq 0 echo ERROR at position 66  && pause

echo [%date% %time%] 位置 67/100: (2.75, 1.53, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos67.pre
if %errorlevel% neq 0 echo ERROR at position 67  && pause

echo [%date% %time%] 位置 68/100: (2.75, 4.00, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos68.pre
if %errorlevel% neq 0 echo ERROR at position 68  && pause

echo [%date% %time%] 位置 69/100: (2.75, 6.47, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos69.pre
if %errorlevel% neq 0 echo ERROR at position 69  && pause

echo [%date% %time%] 位置 70/100: (2.75, 7.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos70.pre
if %errorlevel% neq 0 echo ERROR at position 70  && pause

echo [%date% %time%] 位置 71/100: (7.25, 0.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos71.pre
if %errorlevel% neq 0 echo ERROR at position 71  && pause

echo [%date% %time%] 位置 72/100: (7.25, 1.53, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos72.pre
if %errorlevel% neq 0 echo ERROR at position 72  && pause

echo [%date% %time%] 位置 73/100: (7.25, 4.00, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos73.pre
if %errorlevel% neq 0 echo ERROR at position 73  && pause

echo [%date% %time%] 位置 74/100: (7.25, 6.47, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos74.pre
if %errorlevel% neq 0 echo ERROR at position 74  && pause

echo [%date% %time%] 位置 75/100: (7.25, 7.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos75.pre
if %errorlevel% neq 0 echo ERROR at position 75  && pause

echo [%date% %time%] 位置 76/100: (9.50, 0.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos76.pre
if %errorlevel% neq 0 echo ERROR at position 76  && pause

echo [%date% %time%] 位置 77/100: (9.50, 1.53, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos77.pre
if %errorlevel% neq 0 echo ERROR at position 77  && pause

echo [%date% %time%] 位置 78/100: (9.50, 4.00, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos78.pre
if %errorlevel% neq 0 echo ERROR at position 78  && pause

echo [%date% %time%] 位置 79/100: (9.50, 6.47, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos79.pre
if %errorlevel% neq 0 echo ERROR at position 79  && pause

echo [%date% %time%] 位置 80/100: (9.50, 7.50, 2.35)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos80.pre
if %errorlevel% neq 0 echo ERROR at position 80  && pause

echo [%date% %time%] 位置 81/100: (0.50, 0.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos81.pre
if %errorlevel% neq 0 echo ERROR at position 81  && pause

echo [%date% %time%] 位置 82/100: (0.50, 1.53, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos82.pre
if %errorlevel% neq 0 echo ERROR at position 82  && pause

echo [%date% %time%] 位置 83/100: (0.50, 4.00, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos83.pre
if %errorlevel% neq 0 echo ERROR at position 83  && pause

echo [%date% %time%] 位置 84/100: (0.50, 6.47, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos84.pre
if %errorlevel% neq 0 echo ERROR at position 84  && pause

echo [%date% %time%] 位置 85/100: (0.50, 7.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos85.pre
if %errorlevel% neq 0 echo ERROR at position 85  && pause

echo [%date% %time%] 位置 86/100: (2.75, 0.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos86.pre
if %errorlevel% neq 0 echo ERROR at position 86  && pause

echo [%date% %time%] 位置 87/100: (2.75, 1.53, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos87.pre
if %errorlevel% neq 0 echo ERROR at position 87  && pause

echo [%date% %time%] 位置 88/100: (2.75, 4.00, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos88.pre
if %errorlevel% neq 0 echo ERROR at position 88  && pause

echo [%date% %time%] 位置 89/100: (2.75, 6.47, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos89.pre
if %errorlevel% neq 0 echo ERROR at position 89  && pause

echo [%date% %time%] 位置 90/100: (2.75, 7.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos90.pre
if %errorlevel% neq 0 echo ERROR at position 90  && pause

echo [%date% %time%] 位置 91/100: (7.25, 0.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos91.pre
if %errorlevel% neq 0 echo ERROR at position 91  && pause

echo [%date% %time%] 位置 92/100: (7.25, 1.53, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos92.pre
if %errorlevel% neq 0 echo ERROR at position 92  && pause

echo [%date% %time%] 位置 93/100: (7.25, 4.00, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos93.pre
if %errorlevel% neq 0 echo ERROR at position 93  && pause

echo [%date% %time%] 位置 94/100: (7.25, 6.47, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos94.pre
if %errorlevel% neq 0 echo ERROR at position 94  && pause

echo [%date% %time%] 位置 95/100: (7.25, 7.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos95.pre
if %errorlevel% neq 0 echo ERROR at position 95  && pause

echo [%date% %time%] 位置 96/100: (9.50, 0.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos96.pre
if %errorlevel% neq 0 echo ERROR at position 96  && pause

echo [%date% %time%] 位置 97/100: (9.50, 1.53, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos97.pre
if %errorlevel% neq 0 echo ERROR at position 97  && pause

echo [%date% %time%] 位置 98/100: (9.50, 4.00, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos98.pre
if %errorlevel% neq 0 echo ERROR at position 98  && pause

echo [%date% %time%] 位置 99/100: (9.50, 6.47, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos99.pre
if %errorlevel% neq 0 echo ERROR at position 99  && pause

echo [%date% %time%] 位置 100/100: (9.50, 7.50, 2.70)
D:\Software\FEKO2022\feko\bin\runfeko.exe 8x8x2_pos100.pre
if %errorlevel% neq 0 echo ERROR at position 100  && pause

echo ===== 全部完成 =====
pause
