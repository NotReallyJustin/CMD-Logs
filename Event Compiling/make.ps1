# For mc file
# You MUST run this using Visual Studio if you're a developer
mc -h . -r . -U log_events.mc
rc .\log_events.rc
."C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.16.27023\bin\HostX64\x64\link.exe" -dll -noentry ./log_events.res