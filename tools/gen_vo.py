"""Announcer voice lines: Windows text-to-speech, processed into radio comms.

    python tools/gen_vo.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

import gen_audio as A

LINES = {
    "vo_friendly_uav": "Friendly pulse scan online.",
    "vo_enemy_uav": "Enemy pulse scan spotted.",
    "vo_friendly_jammer": "Jammer active. Enemy radar is down.",
    "vo_enemy_jammer": "Enemy jammer. We've lost radar.",
    "vo_friendly_emp": "Blackout pulse detonated. Enemy systems offline.",
    "vo_enemy_emp": "Enemy blackout pulse. Our systems are offline.",
    "vo_friendly_airstrike": "Strike inbound on your mark.",
    "vo_enemy_airstrike": "Enemy air strike incoming. Take cover.",
    "vo_friendly_air": "Friendly air support on station.",
    "vo_enemy_air": "Enemy aircraft overhead.",
    "vo_match_start": "Operation is a go. Eliminate all hostiles.",
    "vo_victory": "Mission accomplished. Good work.",
    "vo_defeat": "Mission failed. Regroup and try again.",
    "vo_doomsday": "Doomsday inbound. Brace for impact.",
    "vo_flag_taken": "We have taken the objective.",
    "vo_flag_lost": "We have lost the objective.",
    "vo_streak_ready": "Streak reward ready.",
    "vo_crate": "Supply crate inbound.",
    "vo_sentry": "Sentry deployed.",
    "vo_one_minute": "One minute remaining.",
    "vo_winning": "We are winning.",
    "vo_losing": "We are losing. Push forward.",
}


def tts(text, path):
    ps = (
        "Add-Type -AssemblyName System.Speech; "
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        "$v = $s.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Gender -eq 'Male' } | Select-Object -First 1; "
        "if ($v) { $s.SelectVoice($v.VoiceInfo.Name) }; "
        "$s.Rate = 1; "
        "$s.SetOutputToWaveFile('%s'); $s.Speak('%s'); $s.Dispose()" % (path, text.replace("'", "''"))
    )
    subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps], check=True)


def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        n = w.getnframes()
        ch = w.getnchannels()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
        if ch > 1:
            data = data.reshape(-1, ch).mean(axis=1)
    if sr != A.SR:
        idx = np.arange(0, len(data), sr / A.SR)
        data = np.interp(idx, np.arange(len(data)), data)
    return data


def radio(x):
    x = A.biquad(x, "hp", 380, 0.7)
    x = A.biquad(x, "lp", 3400, 0.7)
    x = A.biquad(x, "peak", 1800, 1.0, 5.0)
    x = A.sat(x * 3.0, 2.5)
    x = x + A.noise(len(x) / A.SR) * 0.012
    click = A.biquad(A.noise(0.03), "bp", 2500, 2.0) * A.env_exp(0.03, 0.006) * 0.4
    hiss = A.biquad(A.noise(0.12), "hp", 2000) * A.env_exp(0.12, 0.06) * 0.15
    return np.concatenate([click, np.zeros(int(A.SR * 0.04)), x, hiss, click * 0.7])


def main():
    tmp = tempfile.mkdtemp()
    for name, text in LINES.items():
        p = os.path.join(tmp, name + ".wav")
        tts(text, p)
        A.write(name, radio(read_wav(p)), 0.9)


if __name__ == "__main__":
    main()
