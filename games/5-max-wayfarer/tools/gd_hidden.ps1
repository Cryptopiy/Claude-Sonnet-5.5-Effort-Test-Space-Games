# Launch a program on a PRIVATE Windows desktop object (not the user's visible one).
# Windows created by the process live on that desktop: they can never appear on the user's screen,
# never take focus, never show in the taskbar. stdout+stderr are written to -LogPath.
# The process runs inside a Job Object with a HARD MEMORY CAP (-MaxMemMB, committed memory): a runaway allocation makes the
# process fail by itself instead of exhausting the memory of the whole machine (a test run once took the PC down that way).
# Only the process started here is ever terminated (by handle).
param(
	[Parameter(Mandatory = $true)][string]$Exe,
	[string]$ArgLine = "",
	[string]$WorkDir = "",
	[string]$LogPath = "",
	[int]$TimeoutSec = 60,
	[int]$MaxMemMB = 6144
)
$ErrorActionPreference = "Stop"
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class HiddenDesk {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct STARTUPINFO {
		public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
	[StructLayout(LayoutKind.Sequential)]
	public struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; [MarshalAs(UnmanagedType.Bool)] public bool bInheritHandle; }
	[StructLayout(LayoutKind.Sequential)]
	public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
		public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
		public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
		public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
	}
	[StructLayout(LayoutKind.Sequential)]
	public struct IO_COUNTERS { public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount, ReadTransferCount, WriteTransferCount, OtherTransferCount; }
	[StructLayout(LayoutKind.Sequential)]
	public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
		public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo;
		public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit; public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
	}

	[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
	[DllImport("user32.dll", SetLastError = true)] public static extern bool CloseDesktop(IntPtr h);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern IntPtr CreateFile(string name, uint access, uint share, ref SECURITY_ATTRIBUTES sa, uint disp, uint flags, IntPtr tmpl);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr CreateJobObject(IntPtr attrs, string name);
	[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint size);
	[DllImport("kernel32.dll", SetLastError = true)] public static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
	[DllImport("kernel32.dll", SetLastError = true)] public static extern uint ResumeThread(IntPtr thread);
	[DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
	[DllImport("kernel32.dll")] public static extern bool TerminateProcess(IntPtr h, uint code);
	[DllImport("kernel32.dll")] public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
	[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);

	// returns a job object whose processes may commit at most maxMemBytes (and die with the job), or IntPtr.Zero on failure
	static IntPtr MakeCappedJob(ulong maxMemBytes) {
		IntPtr job = CreateJobObject(IntPtr.Zero, null);
		if (job == IntPtr.Zero) return IntPtr.Zero;
		var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
		info.BasicLimitInformation.LimitFlags = 0x100 | 0x200 | 0x2000;   // PROCESS_MEMORY | JOB_MEMORY | KILL_ON_JOB_CLOSE
		info.ProcessMemoryLimit = new UIntPtr(maxMemBytes);
		info.JobMemoryLimit = new UIntPtr(maxMemBytes);
		int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
		IntPtr p = Marshal.AllocHGlobal(size);
		Marshal.StructureToPtr(info, p, false);
		bool ok = SetInformationJobObject(job, 9, p, (uint)size);
		Marshal.FreeHGlobal(p);
		if (!ok) { CloseHandle(job); return IntPtr.Zero; }
		return job;
	}

	public static string Run(string exe, string args, string cwd, string log, int timeoutSec, ulong maxMemBytes) {
		IntPtr job = MakeCappedJob(maxMemBytes);
		if (job == IntPtr.Zero) return "ERROR: could not create the memory-capped job object " + Marshal.GetLastWin32Error() + " - not starting";
		string deskName = "WayfarerTestDesk" + Guid.NewGuid().ToString("N").Substring(0, 8);
		IntPtr desk = CreateDesktop(deskName, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);
		if (desk == IntPtr.Zero) { CloseHandle(job); return "ERROR: CreateDesktop failed " + Marshal.GetLastWin32Error(); }
		IntPtr hLog = IntPtr.Zero;
		var sa = new SECURITY_ATTRIBUTES(); sa.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)); sa.bInheritHandle = true;
		var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
		si.lpDesktop = deskName;
		if (!string.IsNullOrEmpty(log)) {
			hLog = CreateFile(log, 0x40000000, 1, ref sa, 2, 0x80, IntPtr.Zero);
			si.dwFlags = 0x100; si.hStdOutput = hLog; si.hStdError = hLog; si.hStdInput = IntPtr.Zero;
		}
		var sb = new StringBuilder("\"" + exe + "\" " + args);
		PROCESS_INFORMATION pi;
		// CREATE_NO_WINDOW | BELOW_NORMAL_PRIORITY | CREATE_SUSPENDED: the process joins the capped job before it executes a single instruction
		bool ok = CreateProcess(null, sb, IntPtr.Zero, IntPtr.Zero, true, 0x08004004, IntPtr.Zero, string.IsNullOrEmpty(cwd) ? null : cwd, ref si, out pi);
		if (!ok) { int e = Marshal.GetLastWin32Error(); if (hLog != IntPtr.Zero) CloseHandle(hLog); CloseDesktop(desk); CloseHandle(job); return "ERROR: CreateProcess failed " + e; }
		if (!AssignProcessToJobObject(job, pi.hProcess)) {
			int e2 = Marshal.GetLastWin32Error();
			TerminateProcess(pi.hProcess, 1); CloseHandle(pi.hProcess); CloseHandle(pi.hThread);
			if (hLog != IntPtr.Zero) CloseHandle(hLog); CloseDesktop(desk); CloseHandle(job);
			return "ERROR: AssignProcessToJobObject failed " + e2 + " - process killed";
		}
		ResumeThread(pi.hThread);
		uint w = WaitForSingleObject(pi.hProcess, (uint)(timeoutSec * 1000));
		string res;
		if (w == 0x102) { TerminateProcess(pi.hProcess, 1); WaitForSingleObject(pi.hProcess, 3000); res = "TIMEOUT after " + timeoutSec + "s, terminated PID " + pi.dwProcessId; }
		else { uint code; GetExitCodeProcess(pi.hProcess, out code); res = "exit=" + code + " pid=" + pi.dwProcessId; }
		CloseHandle(pi.hProcess); CloseHandle(pi.hThread);
		if (hLog != IntPtr.Zero) CloseHandle(hLog);
		CloseDesktop(desk);
		CloseHandle(job);
		return res;
	}
}
"@
$res = [HiddenDesk]::Run($Exe, $ArgLine, $WorkDir, $LogPath, $TimeoutSec, [uint64]$MaxMemMB * 1MB)
Write-Output $res
