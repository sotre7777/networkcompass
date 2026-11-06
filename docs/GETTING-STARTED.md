# Getting started, step by step

No coding needed. You type a few commands, and Claude does the rest. Copy each command exactly.

**You need:** a Mac with macOS 14 or newer, or a Windows 10 or 11 PC, plus a LinkedIn account and a paid Claude plan (Claude Code needs one). Where steps differ, follow the part for your computer.

**Time:** about 10 minutes to install, 15 minutes for the setup conversation, and about an hour for the analysis, which mostly runs by itself. LinkedIn can take up to a day to prepare your data, so do step 1 first.

## 1. Request your LinkedIn data (do this first)

1. On LinkedIn, open **Settings & Privacy**, then **Data privacy**, then **Get a copy of your data**.
2. Choose the larger archive with **all files**, not just Connections.
3. LinkedIn emails you when it is ready. You can do steps 2 to 5 while you wait.

## 2. Download Network Compass

1. Go to [github.com/sotre7777/networkcompass](https://github.com/sotre7777/networkcompass), click the green **Code** button, then **Download ZIP**.
2. Open the ZIP from your Downloads folder.
3. Move the folder `networkcompass-main` into your **Documents** folder.
   - **Windows:** right-click the ZIP, choose **Extract All**, and extract it to Documents. If you get a folder inside a folder, move the inner one up.

## 3. Open a command window in that folder

**Mac:** open **Terminal** (press ⌘ Space, type Terminal, press Return). Then copy this in and press Return:

```bash
cd ~/Documents/networkcompass-main
```

**Windows:** press the Windows key, type **PowerShell**, press Return. Then copy this in and press Return:

```powershell
cd $HOME\Documents\networkcompass-main
```

If your Documents folder is in OneDrive, use `cd $HOME\OneDrive\Documents\networkcompass-main`.

## 4. Install Claude Code

**Mac:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows:** first install two free programs, accepting the defaults:

- [Git for Windows](https://git-scm.com/downloads/win)
- [Python](https://www.python.org/downloads/). In the installer, tick **Add python.exe to PATH**.

Then close PowerShell, open it again, repeat step 3, and run:

```powershell
irm https://claude.ai/install.ps1 | iex
```

If it tells you to run a command or open a new window to finish, do that, and repeat step 3.

## 5. Set everything up

**Mac:**

```bash
zsh setup.sh
```

If a window asks to install Apple's command line tools, click **Install**, wait until it finishes, and run the same command again.

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

You are done when it says **All set**.

## 6. Have the setup conversation

Mac and Windows:

```bash
claude
```

The first time, it asks you to sign in with your Claude account and whether you trust this folder. Say yes. Then type:

```
/setup-network
```

Claude asks you one question at a time about what you are looking for: a job, or clients and opportunities. It helps you name your own categories. There are no wrong answers, and you can change everything later. It ends by writing your profile.

Claude sometimes asks permission to run a command or edit a file. For commands in this project, choose Yes.

## 7. Put your LinkedIn data in place

When LinkedIn's email arrives, download the ZIP and open it. Move **everything inside** into the `export` folder in `networkcompass-main`. You should now have the file `export/Connections.csv`.

Not sure? Ask Claude: "Is my LinkedIn export in the right place?"

## 8. Run the analysis

In Claude Code, type:

```
/mine-network
```

Claude goes through every connection, reads the titles, estimates company sizes and writes opening lines. It stops twice to show you what it found. Plan for about an hour, and you can do other things while it works.

## 9. Open the app

**Mac:** open **Network Compass** from the **Applications** folder inside your home folder, and drag it to your Dock. Allow notifications, so check-in reminders can reach you. If macOS warns about the app, right-click it, choose **Open**, and confirm. You only do this once.

**Windows:** double-click **Network Compass** on your desktop. A small black window opens, then your browser. Keep the black window open while you work, and close it when you are done. The app itself only runs on your PC. Windows may ask you to confirm that the file can run: choose **More info**, then **Run anyway**.

**On Windows, reminders show inside the app, not as notifications.** Today lists who is due, and the browser tab shows the number. Open the app regularly to see them.

## Using it day to day

- **Today** shows who is due a check-in this week.
- **Lists and stages** are in the sidebar. Rename them under Network Compass, Settings (⌘,).
- **Log a touchpoint** on a contact after each contact moment, and set when to check in again.
- **Change a stage or list** on the contact itself. On a Mac, ⌘1, ⌘2 and so on set the stage, and right-clicking a contact moves it to another list.
- **New contact** (⌘N on a Mac) adds someone who is not on LinkedIn.
- **Notes for Claude:** write what only you know on a contact, such as "former colleague, informal" or "not relevant, ignore". Then open a command window, go to the folder (step 3), type `claude`, and type `/process-notes`.

## If something goes wrong

| What you see | What to do |
|---|---|
| `command not found: claude`, or `claude` is not recognized | Open a new window, repeat step 3, then try again. If it stays, repeat step 4. |
| `no such file or directory`, or a path that cannot be found | The folder is somewhere else or has another name. Check that `networkcompass-main` is in Documents. |
| Windows: Python is missing, or opens the Microsoft Store | Install Python from python.org and tick **Add python.exe to PATH**. |
| Windows: the black window closes at once | Run `python webapp\server.py` from the folder to see the message, or ask Claude. |
| `No profile.json yet` | Run `/setup-network` first. |
| `No export/Connections.csv` | Redo step 7. The file must be directly in `export`, not in a folder inside it. |
| The app shows no contacts | Finish `/mine-network`, then check Settings, Data file. |
| Anything else | Type `claude` and describe what happened in plain words. It can read this project and help. |

## Your data

Your LinkedIn data and results stay in this folder on your Mac. Claude Code sends what it reads to Anthropic to do the work, including the names and titles it reviews. Your export also contains other people's details, so do not share it, and delete the ZIP when you are done.
