@echo on

mkdir build
if errorlevel 1 exit /b 1
cd build

:: PXR_PYTHON_INSTALL_DIR pins the Python bindings to lib/python (the location
:: used before OpenUSD 26.08). As of 26.08 it defaults to a Lib\site-packages
:: layout, which would break the "move lib\python\pxr" step below.
:: Anaconda: the extras examples are disabled on win-arm64 because
:: irExampleUsdviewPlugin is a python plugin that imports pxr.Usdviewq.qt and
:: would otherwise be installed without Qt.
set "PXR_BUILD_USDVIEW=ON"
set "PXR_BUILD_EXAMPLES=ON"
if "%target_platform%"=="win-arm64" set "PXR_BUILD_EXAMPLES=OFF"

:: Anaconda: upstream looks for the Qt Designer uic executable using
:: PYSIDEUICBINARY. On Anaconda main, PySide6's wrapper is patched to call
:: %PREFIX%\Library\lib\qt6\uic.exe, but there is no `uic` on PATH inside the
:: PySide6 package itself: the executable ships in qtbase-devel at
:: %PREFIX%\Library\lib\qt6\uic.exe. Use it directly to avoid depending on
:: the patched wrapper's hard-coded path.
if "%PXR_BUILD_USDVIEW%"=="ON" (
set CMAKE_ARGS=%CMAKE_ARGS% -DPYSIDEUICBINARY="%PREFIX%\Library\lib\qt6\uic.exe"
)

cmake %CMAKE_ARGS% ^
    -G "Ninja" ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_SHARED_LIBS:BOOL=ON ^
    -DPXR_HEADLESS_TEST_MODE:BOOL=ON ^
    -DPXR_BUILD_IMAGING:BOOL=ON ^
    -DPXR_BUILD_USD_IMAGING=ON ^
    -DPXR_BUILD_USDVIEW:BOOL=%PXR_BUILD_USDVIEW% ^
    -DPXR_BUILD_EXAMPLES:BOOL=%PXR_BUILD_EXAMPLES% ^
    -DPXR_ENABLE_PYTHON_SUPPORT=ON ^
    -DPXR_PYTHON_SHEBANG="/usr/bin/env python" ^
    -DPXR_PYTHON_INSTALL_DIR=lib/python ^
    -DPython3_EXECUTABLE=%PYTHON% ^
    -DPXR_INSTALL_DLL_IN_BIN:BOOL=ON ^
    %SRC_DIR%
if errorlevel 1 exit /b 1

:: Build.
cmake --build . --config Release --parallel %CPU_COUNT%
if errorlevel 1 exit /b 1

:: Install.
cmake --build . --config Release --parallel %CPU_COUNT% --target install
if errorlevel 1 exit /b 1

:: Test.
:: testWorkThreadLimits is disabled as it can fail on machines with few cores
:: testUsdResolverExample is disabled as it expects some kind of RPATH-like loading of .dll
:: TfPathUtils fails for some reason in CI but not locally,
::             see https://github.com/conda-forge/openusd-feedstock/pull/6#issuecomment-2888315313
:: testWorkDispatcher and testUsdUtilsFlattenLayerStack are disabled as they are flaky, and they can silently fail a post-PR CI job,
:: resulting in a package (for example for a given Python version) silently not being uploaded
:: testExecGeomXformable_Perf_Large is disabled as it is disabled upstream, see 
:: https://github.com/PixarAnimationStudios/OpenUSD/blob/v25.11/.github/workflows/buildusd.yml#L83
:: --no-tests=ignore keeps ctest from erroring when no tests are registered
:: (recent ctest defaults that action to "error").
ctest --output-on-failure --no-tests=ignore -C Release -E "testWorkThreadLimits|testUsdResolverExample|TfPathUtils|testWorkDispatcher|testUsdUtilsFlattenLayerStack|testExecGeomXformable_Perf_Large"
if errorlevel 1 exit /b 1

:: The CMake install logic of openusd is not flexible, so let's fix the files
:: that should not be installed or should be installed in a different location

:: Python files should be moved from $CMAKE_INSTALL_PREFIX/lib/python/pxr to $SP_DIR/pxr
move "%LIBRARY_PREFIX%\lib\python\pxr" "%SP_DIR%\pxr"
if errorlevel 1 exit /b 1


:: All files installed in $CMAKE_INSTALL_PREFIX/tests, $CMAKE_INSTALL_PREFIX/share/usd/examples and $CMAKE_INSTALL_PREFIX/share/usd/tutorials can be removed
if exist "%LIBRARY_PREFIX%\tests" rd /s /q "%LIBRARY_PREFIX%\tests"
if errorlevel 1 exit /b 1

if exist "%LIBRARY_PREFIX%\share\usd\examples" rd /s /q "%LIBRARY_PREFIX%\share\usd\examples"
if errorlevel 1 exit /b 1

if exist "%LIBRARY_PREFIX%\share\usd\tutorials" rd /s /q "%LIBRARY_PREFIX%\share\usd\tutorials"
if errorlevel 1 exit /b 1

REM This logic is to ensure that pip list lists usd-core (https://pypi.org/project/usd-core/) as installed package
REM The version style is a bit different: openusd version are something like 22.01, 23.05.01, 24.11 while usd-core are 22.1, 23.5.1, 24.11
REM so we convert all occurences of .0 to . if present, to convert from one style to another
set "PIP_USD_CORE_VERSION=%PKG_VERSION:.0=.%"

REM The METADATA file is necessary to ensure that pip list shows the pip package installed by conda
REM The INSTALLER file is necessary to ensure that pip list shows that the package is installed by conda
REM See https://packaging.python.org/specifications/recording-installed-packages/
REM and https://packaging.python.org/en/latest/specifications/core-metadata/#core-metadata

mkdir "%SP_DIR%\usd_core-%PIP_USD_CORE_VERSION%.dist-info"
if errorlevel 1 exit /b 1

set metadata_file=%SP_DIR%\usd_core-%PIP_USD_CORE_VERSION%.dist-info\METADATA
echo>%metadata_file% Metadata-Version: 2.1
echo>>%metadata_file% Name: usd-core
echo>>%metadata_file% Version: %PIP_USD_CORE_VERSION%
echo>>%metadata_file% Summary: Pixar's Universal Scene Description

set installer_file=%SP_DIR%\usd_core-%PIP_USD_CORE_VERSION%.dist-info\INSTALLER
echo>%installer_file% conda
