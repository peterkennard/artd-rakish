#include "stdafx.h"
#include <string>
#include <cstdio>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <array>
#include <thread>
#include <algorithm> 
#include <cctype>
#include <locale>


using namespace std;

//
// Execute a command and get the results. (Only standard output)
// without opening a window
//
string ExecCmd(	const char* cmd ) 
{
	string strResult;
	HANDLE hPipeRead, hPipeWrite;

	SECURITY_ATTRIBUTES saAttr = { sizeof(SECURITY_ATTRIBUTES) };
	saAttr.bInheritHandle = TRUE;   //Pipe handles are inherited by child process.
	saAttr.lpSecurityDescriptor = NULL;

	// Create a pipe to get results from child's stdout.
	if (!CreatePipe(&hPipeRead, &hPipeWrite, &saAttr, 0))
		return strResult;

	STARTUPINFO si = { sizeof(STARTUPINFO) };
	si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
	si.hStdOutput = hPipeWrite;
	si.hStdError = hPipeWrite;
	si.wShowWindow = SW_HIDE;       // Prevents cmd window from flashing. Requires STARTF_USESHOWWINDOW in dwFlags.

	PROCESS_INFORMATION pi = { 0 };

	BOOL fSuccess = CreateProcess(NULL, (LPSTR)cmd, NULL, NULL, TRUE, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi);
	if (!fSuccess)
	{
		CloseHandle(hPipeWrite);
		CloseHandle(hPipeRead);
		return strResult;
	}

	bool bProcessEnded = false;
	
	for (; !bProcessEnded;)
	{
		// Give some timeslice (50ms), so we won't waste 100% cpu.
		bProcessEnded = WaitForSingleObject(pi.hProcess, 50) == WAIT_OBJECT_0;

		// Even if process exited - we continue reading, if there is some data available over pipe.
		for (;;)
		{
			char buf[1024];
			DWORD dwRead = 0;
			DWORD dwAvail = 0;

			if (!::PeekNamedPipe(hPipeRead, NULL, 0, NULL, &dwAvail, NULL))
				break;

			if (!dwAvail) // no data available, return
				break;

			if (!::ReadFile(hPipeRead, buf, min(sizeof(buf) - 1, dwAvail), &dwRead, NULL) || !dwRead)
				// error, the child process might ended
				break;

			buf[dwRead] = 0;
			strResult += buf;
		}
	} //for

	CloseHandle(hPipeWrite);
	CloseHandle(hPipeRead);
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);
	return strResult;
} //ExecCmd


/*
// trim from start(in place)
static inline void ltrim(std::string &s) {
	s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](int ch) {
		return !std::isspace(ch);
	}));
}
*/

// trim from end (in place)
static inline void rtrim(std::string &s) {
	s.erase(std::find_if(s.rbegin(), s.rend(), [](int ch) {
		return !std::isspace(ch);
	}).base(), s.end());
}

/*
// trim from both ends (in place)
static inline void trim(std::string &s) {
	ltrim(s);
	rtrim(s);
}

// trim from start (copying)
static inline std::string ltrim_copy(std::string s) {
	ltrim(s);
	return s;
}

// trim from end (copying)
static inline std::string rtrim_copy(std::string s) {
	rtrim(s);
	return s;
}

// trim from both ends (copying)
static inline std::string trim_copy(std::string s) {
	trim(s);
	return s;
}
*/

int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
                     _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR    lpCmdLine,
                     _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);

	string res = ExecCmd("where artd-shell.bat");
	rtrim(res);
	char cmd[1024];
	snprintf(cmd, sizeof(cmd), "\"%s\" -c \"artd-rakish-find %ls\"", res.c_str(), lpCmdLine);

	res = ExecCmd(cmd);
	printf(res.c_str());

	return (int)0;
}
