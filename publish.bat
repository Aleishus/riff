@echo off
:: ##########################################################################
::  riff demo command for Windows to publish messages
:: ##########################################################################

:: set local scope for the variables with windows NT shell
if [%OS%]==[Windows_NT] setlocal

call :capture_instances svc "http-gateway"
if "%svc%"=="[]" (
  echo Unable to locate the http-gateway
  exit /B 1
)

call :capture_jsonpath svc_type "http-gateway" "{.items[0].spec.type}"
if [%svc_type%]==[NodePort] (
  call :capture_cmd address "minikube ip"
  call :capture_jsonpath port "http-gateway" "{.items[0].spec.ports[?(@.name == 'http')].nodePort}"
  goto do_curl
)

call :capture_jsonpath address "http-gateway" "{.items[0].status.loadBalancer.ingress[0].ip}"
if [%address%]==[] (
  echo External IP is not yet available, try in a few ...
  exit /B 1
)
call :capture_jsonpath port "http-gateway" "{.items[0].spec.ports[?(@.name == 'http')].port}"

:do_curl
if [%3]==[] (
    set count=1
) else (
    set count=%3
)
if [%4]==[] (
    set pause=0
) else (
    set pause=%4
)
for /L %%i in (1,1,%count%) do call :do_post_content %~1 %~2 %%i
echo.

exit /B %ERRORLEVEL%

:do_post_content
curl -H "Content-Type: text/plain" -X POST http://%address%:%port%/messages/%1 -d "%2"
timeout /t %pause% /nobreak > NUL
exit /B %ERRORLEVEL%

:capture_cmd
for /f "tokens=* usebackq" %%f in (`%~2`) do (
  set %1=%%f
)
exit /B %ERRORLEVEL%

:capture_instances
set _tmp_file=%tmp%riff-%random%.txt
kubectl get svc -l component=%~2 -o jsonpath="{.items}" >  %_tmp_file%
for /f "delims= tokens=1" %%x in (%_tmp_file%) do set %1=%%x
del %_tmp_file%
exit /B %ERRORLEVEL%

:capture_jsonpath
set _tmp_file=%tmp%\riff-%random%.txt
set _kcmd=kubectl get svc -l component=%~2 -o jsonpath=%3
%_kcmd% > %_tmp_file%
for /f "delims= tokens=1" %%x in (%_tmp_file%) do set %1=%%x
del %_tmp_file%
exit /B %ERRORLEVEL%
