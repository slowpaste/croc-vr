"""Release UI: choose a disc, then press one headset button."""
from datetime import datetime
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from . import __version__
from .common import WORKSPACE, read_json, worker_command, write_json


class DesktopWindow:
    def __init__(self, root):
        self.root, self.process = root, None
        self.busy, self.cancelled = False, False
        self.messages = queue.Queue()
        self.log_position = 0
        self.epoch = 0
        self.output = None
        self.preferences = WORKSPACE/'.cache/desktop.json'
        saved = read_json(self.preferences) if self.preferences.exists() else {}
        root.title('croc of slop VR')
        root.geometry('780x560')
        root.minsize(760, 540)
        style = ttk.Style(root)
        if 'clam' in style.theme_names():
            style.theme_use('clam')
        style.configure('Title.TLabel', font=('Segoe UI', 26, 'bold'))
        style.configure('Headset.TButton', font=('Segoe UI', 12, 'bold'), padding=(18, 18))
        body = ttk.Frame(root, padding=28)
        body.pack(fill='both', expand=True)
        ttk.Label(body, text='croc of slop VR', style='Title.TLabel').pack(anchor='w')
        ttk.Label(body, text='Choose your Croc disc. Build your headset app.').pack(anchor='w', pady=(8, 24))
        ttk.Label(body, text='1. Choose your PlayStation disc backup').pack(anchor='w')
        row = ttk.Frame(body)
        row.pack(fill='x', pady=(8, 22))
        self.disc = tk.StringVar(value=saved.get('disc', ''))
        self.disc_entry = ttk.Entry(row, textvariable=self.disc)
        self.disc_entry.pack(side='left', fill='x', expand=True, padx=(0, 10))
        self.browse_button = ttk.Button(row, text='Choose .bin file…', command=self.choose)
        self.browse_button.pack(side='right')
        ttk.Label(body, text='2. Click your headset').pack(anchor='w')
        actions = ttk.Frame(body)
        actions.pack(fill='x', pady=(8, 18))
        self.buttons = []
        for name, target in [('Build for Steam Frame', 'frame'), ('Build for Facebook Shitface 3', 'quest')]:
            button = ttk.Button(actions, text=name, style='Headset.TButton', command=lambda t=target:self.build(t))
            button.pack(side='left', fill='x', expand=True, padx=(0, 8))
            self.buttons.append(button)
        self.status = tk.StringVar(value='Setup runs automatically when you build.')
        ttk.Label(body, textvariable=self.status, wraplength=690).pack(anchor='w', pady=(0, 10))
        self.progress = ttk.Progressbar(body, mode='indeterminate')
        self.progress.pack(fill='x')
        footer = ttk.Frame(body)
        footer.pack(fill='x', pady=(12, 10))
        self.open_button = ttk.Button(footer, text='Open finished apps', command=self.open_output, state='disabled')
        self.open_button.pack(side='left')
        self.cancel_button = ttk.Button(footer, text='Cancel', command=self.cancel, state='disabled')
        self.cancel_button.pack(side='right')
        ttk.Button(footer, text='Details', command=self.toggle_details).pack(side='right', padx=8)
        self.details = ttk.Frame(body)
        self.log = tk.Text(self.details, height=10, wrap='word', state='disabled', font=('Consolas', 9))
        scroll = ttk.Scrollbar(self.details, command=self.log.yview)
        self.log.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right', fill='y')
        self.log.pack(fill='both', expand=True)
        ttk.Label(body, text='Setup downloads a few GB the first time. Your disc stays on your computer.\nEach app file is under 1 GB; allow more than 2 GB on the headset.', wraplength=690).pack(anchor='w', pady=(12, 4))
        ttk.Label(body, text=f'Version {__version__}', wraplength=690).pack(anchor='w')
        root.after(150, self.poll)
        root.protocol('WM_DELETE_WINDOW', self.close)

    def choose(self):
        value = filedialog.askopenfilename(title='Choose your Croc PlayStation disc backup', filetypes=[('PlayStation disc backup', '*.bin *.iso'), ('All files', '*')])
        if value:
            self.disc.set(value)

    def set_busy(self, busy):
        self.busy = busy
        for control in [*self.buttons, self.browse_button, self.disc_entry]:
            control.configure(state='disabled' if busy else 'normal')
        self.cancel_button.configure(state='normal' if busy else 'disabled')
        self.progress.start(12) if busy else self.progress.stop()

    def build(self, target):
        if self.busy:
            return
        if not Path(self.disc.get()).is_file():
            messagebox.showerror('Choose your disc', 'Choose your Croc PlayStation .bin backup first. A raw .iso also works.')
            return
        from .portable import android_supported
        if target == 'quest' and not android_supported():
            messagebox.showinfo('Linux ARM', 'This download builds for Steam Frame. Android builds need Windows, Mac, or x64 Linux.')
            return
        write_json(self.preferences, {'disc':self.disc.get()})
        self.cancelled = False
        self.epoch += 1
        epoch = self.epoch
        self.set_busy(True)
        if target == 'quest':
            self.status.set('Checking first-time Android setup…')
            def check_terms():
                try:
                    from .portable import sdk_licenses, needs_consent
                    terms = sdk_licenses()
                    if not terms:
                        raise RuntimeError('Could not load the Android setup terms. Please try again later.')
                    self.messages.put((epoch, 'terms', (target, terms if needs_consent(terms) else None)))
                except Exception as error:
                    self.messages.put((epoch, 'error', str(error)))
            threading.Thread(target=check_terms, daemon=True).start()
        else:
            self.start(target)

    def review_terms(self, target, licenses):
        if licenses is None:
            self.start(target)
            return
        dialog = tk.Toplevel(self.root)
        dialog.title('First-time Android setup')
        dialog.geometry('740x580')
        dialog.transient(self.root)
        frame = ttk.Frame(dialog, padding=20)
        frame.pack(fill='both', expand=True)
        ttk.Label(frame, text='Read the Google terms below. Accept them to continue Android setup.', wraplength=690).pack(anchor='w', pady=(0, 12))
        text = tk.Text(frame, wrap='word')
        scroll = ttk.Scrollbar(frame, command=text.yview)
        text.configure(yscrollcommand=scroll.set)
        scroll.pack(side='right', fill='y')
        text.pack(fill='both', expand=True)
        text.insert('end', '\n\n'.join(licenses.values()))
        text.configure(state='disabled')
        buttons = ttk.Frame(frame)
        buttons.pack(fill='x', pady=(12, 0))
        def decline():
            dialog.destroy()
            self.set_busy(False)
            self.status.set('Android setup cancelled.')
        def accept():
            from .portable import record_consent
            record_consent(licenses)
            dialog.destroy()
            self.start(target)
        ttk.Button(buttons, text='Cancel', command=decline).pack(side='right')
        ttk.Button(buttons, text='Accept and continue', command=accept).pack(side='right', padx=10)
        dialog.protocol('WM_DELETE_WINDOW', decline)
        dialog.grab_set()

    def start(self, target):
        if self.cancelled:
            return
        stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        self.output = Path.home()/'Croc of Slop VR'/stamp
        self.log_path = WORKSPACE/'.cache/logs'/f'build-{stamp}.log'
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path.touch()
        self.log_position = 0
        self.open_button.configure(state='disabled')
        self.status.set('Setting up the tools. The first build takes a little longer…')
        env = os.environ.copy()
        env['CROC_WORKER_LOG'] = str(self.log_path)
        options = {'creationflags':subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
        try:
            with self.log_path.open('a', encoding='utf-8') as output:
                self.process = subprocess.Popen(worker_command('desktop-build', '--target', target, '--iso', self.disc.get(), '--output', self.output), stdout=output, stderr=subprocess.STDOUT, env=env, start_new_session=os.name != 'nt', **options)
        except Exception as error:
            self.fail(str(error))

    def toggle_details(self):
        if self.details.winfo_manager():
            self.details.pack_forget()
            self.root.geometry('780x560')
        else:
            self.details.pack(fill='both', expand=True, pady=8)
            self.root.geometry('780x780')

    def append_log(self, text):
        self.log.configure(state='normal')
        self.log.insert('end', text)
        if int(self.log.index('end-1c').split('.')[0]) > 1500:
            self.log.delete('1.0', '200.0')
        self.log.see('end')
        self.log.configure(state='disabled')
        for line in text.splitlines():
            if line.startswith('Downloading '):
                self.status.set('Downloading setup files' + (': ' + line.rsplit(': ', 1)[1] if ': ' in line else '…'))
            elif line.startswith('Exporting '):
                self.status.set('Creating your headset app…')
            elif 'Hashing the selected disc' in line:
                self.status.set('Checking your selected disc…')
            elif 'Running node' in line or 'Running Godot' in line:
                self.status.set('Preparing your game. Leave this window open.')

    def fail(self, detail):
        self.set_busy(False)
        self.status.set('Could not finish. Open Details to see what went wrong.')
        self.append_log(detail + '\n')
        if not self.details.winfo_manager():
            self.toggle_details()

    def poll(self):
        while not self.messages.empty():
            epoch, kind, value = self.messages.get_nowait()
            if not self.cancelled and epoch == self.epoch:
                self.review_terms(*value) if kind == 'terms' else self.fail(value)
        if self.process is not None:
            with self.log_path.open(encoding='utf-8', errors='replace') as stream:
                stream.seek(self.log_position)
                text = stream.read()
                self.log_position = stream.tell()
            if text:
                self.append_log(text)
            code = self.process.poll()
            if code is not None:
                self.process = None
                self.set_busy(False)
                if self.cancelled:
                    self.status.set('Build cancelled.')
                elif code == 0 and (self.output/'build-report.json').exists():
                    self.status.set('Your app is ready. Click Open finished apps.')
                    self.open_button.configure(state='normal')
                else:
                    self.fail('Build stopped. See the error above.\nLog file: ' + str(self.log_path))
        self.root.after(150, self.poll)

    def open_output(self):
        if self.output and self.output.exists():
            if os.name == 'nt':
                os.startfile(self.output)
            else:
                subprocess.Popen(['open' if sys.platform == 'darwin' else 'xdg-open', str(self.output)])

    def cancel(self):
        self.cancelled = True
        self.epoch += 1
        process = self.process
        if process is not None and process.poll() is None:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                import signal
                os.killpg(process.pid, signal.SIGTERM)
        else:
            self.set_busy(False)
            self.status.set('Setup cancelled.')

    def close(self):
        if self.busy:
            messagebox.showinfo('Build in progress', 'Cancel the build before closing this window.')
        else:
            self.root.destroy()


def launch():
    root = tk.Tk()
    DesktopWindow(root)
    root.mainloop()
