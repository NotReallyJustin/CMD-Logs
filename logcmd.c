#include <windows.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "log_events.h"

/**
 * Max length of a `cmd.exe` command is 8191 characters
 * @see https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/command-line-string-limitation
 */
#define MAX_COMMAND_LEN 8191

char curr_dir[MAX_PATH];

/**
 * Logs a command being run in the Windows Registry. 
 * This requires log_events.dll and log_events.h to be generated from the .mc file using Windows SDK
 * @param command Text of command being run.
 */
void log_event(char* command) 
{
    HANDLE event_source = RegisterEventSource(NULL, "cmdexe");
    if (event_source == NULL) 
    {
        fprintf(stderr, "Failed to log event: could not register the event source.\n");
        return;
    }

    // Write param to general event viewer tab
    char* params[2];
    params[0] = command;
    params[1] = strlen(curr_dir) == 0 ? "Path Unavailable" : curr_dir;

    if (!ReportEvent(event_source, EVENTLOG_INFORMATION_TYPE, 0, MSG_CMD_EXEC, NULL, 2, 0, params, NULL)) 
    {
        fprintf(stderr, "Failed to log event: ReportEvent() failed with status %d.\n", GetLastError());
    }

    DeregisterEventSource(event_source);
}

/**
 * Update working directory. Basically, update the $curr_dir variable.
 */
void update_wd()
{
    DWORD status = GetCurrentDirectory(MAX_PATH, curr_dir);

    if (status == 0)
    {
        fprintf(stderr, "Failed to update current directory: GetCurrentDirectory() failed with status %d.\n", GetLastError());
    }
    else if (status > MAX_PATH)
    {
        fprintf(stderr, "Failed to update current directory: $path is too large. I don't even know how this happens because Windows restricts the MAX_PATH size, but good job.\n");
    }
}

/**
 * Changes the program's current directory and updates respective variables
 * @param new_path Path to set the cmd.exe's directory to
 */
void change_dir(char* new_path)
{
    if (!SetCurrentDirectory(new_path))
    {
        fprintf(stderr, "Failed to change directory to %s with status %d.\n", new_path, GetLastError());
    }
    else
    {
        update_wd();
    }
}

/**
 * Prints working directory just like how cmd.exe does it
 */
void pwd()
{
    if (strlen(curr_dir) == 0)
    {
        fprintf(stderr, "Failed to print woring directory: call update_pwd() first.\n");
    }
    else
    {
        printf("%s> ", curr_dir);
    }
}

/**
 * Detect if a command is asking us to $cd somewhere. If it is, process it.
 * @param command The input command to "cmd.exe"
 */
void process_cd(char* command)
{
    int new_dir_idx = 0;

    for (int i = 0; i < strlen(command) - 1; i++)
    {
        if (command[i] == ' ')
        {
            continue;
        }
        else if (
            (command[i] == 'c') && (command[i + 1] == 'd')
        )
        {
            new_dir_idx = i + 3;

            // A plain $cd does nothing
            if (i + 3 > strlen(command))
            {
                return;
            }

            break;
        }
        else
        {
            // We don't have "$cd"
            return;
        }
    }

    char new_dir[MAX_PATH];

    // Copy and trim whitespace
    while (isspace(command[new_dir_idx]))
    {
        new_dir_idx++;
    }

    // In case everything is a whitespace - we don't need to do anything
    if (command[new_dir_idx] == '\0')
    {
        return;
    }

    char* end = command + strlen(command) - 1;
    while (end > command && isspace(*end))
    {
        end--;
    }

    *(end + 1) = '\0';

    strncpy(new_dir, command + new_dir_idx, MAX_PATH);
    change_dir(new_dir);
}

/**
 * Detects if the user typed "exit". If they did, handle it.
 * @param command The user command
 */
void process_exit(char* command)
{
    if (strstr(command, "exit"))
    {
        exit(0);
    }
}

int main() 
{
    update_wd();

    // Wrapper for cmd.exe. We're abiding by most cmd.exe rules
    char line[MAX_COMMAND_LEN];

    while (1)
    {
        pwd();
        if (fgets(line, MAX_COMMAND_LEN, stdin) == NULL)
        {
            perror("Error reading command input.");
        }
        else
        {
            // system() can print things directly to stderr if they go wrong.
            system(line);
            log_event(line);

            // Make everything lowercase
            for (int i = 0; i < strlen(line); i++)
            {
                line[i] = tolower(line[i]);    
            }
            
            process_cd(line);
            process_exit(line);
        }

        // Reset input line
        memset(line, 0, MAX_COMMAND_LEN);
    }

    return 0;
}