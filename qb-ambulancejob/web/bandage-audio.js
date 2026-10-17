// Dedicated, background-only FiveM NUI sound player.
// Audio comes from interact-sound's existing streamed OGG file.
// The HTMLAudioElement is controllable, unlike interact-sound's one-shot event.
const playing = new Map();

function stop(id) {
    const entry = playing.get(id);
    if (!entry) return;
    clearTimeout(entry.timeout);
    entry.audio.pause();
    entry.audio.currentTime = 0;
    entry.audio.removeAttribute('src');
    entry.audio.load();
    playing.delete(id);
}

function stopAll() {
    for (const id of [...playing.keys()]) stop(id);
}

window.addEventListener('message', ({data}) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'bandage:stopAll') {
        stopAll();
        return;
    }
    const id = String(data.id ?? '');
    if (!id) return;
    if (data.action === 'bandage:stop') {
        stop(id);
        return;
    }
    if (data.action !== 'bandage:start') return;

    stop(id);
    const resource = String(data.resource || 'interact-sound');
    const name = String(data.name || 'bandage').replace(/\.ogg$/i, '');
    // Do not permit arbitrary paths; the sound is an .ogg in interact-sound.
    if (!/^[a-z0-9_-]+$/i.test(resource) || !/^[a-z0-9_-]+$/i.test(name)) return;

    const audio = new Audio(`https://cfx-nui-${resource}/client/html/sounds/${name}.ogg`);
    audio.preload = 'auto';
    audio.loop = true;
    audio.volume = Math.max(0, Math.min(1, Number(data.volume) || 0));
    const duration = Math.max(500, Math.min(30000, Number(data.duration) || 4000));
    const timeout = setTimeout(() => stop(id), duration + 2500);
    playing.set(id, {audio, timeout});
    audio.addEventListener('error', () => {
        console.error(`[qb-ambulancejob] Cannot load ${name}.ogg from ${resource}. Check its fxmanifest.lua files.`);
        stop(id);
    }, {once:true});
    audio.play().catch((error) => {
        console.error('[qb-ambulancejob] Bandage loop playback failed:', error);
        stop(id);
    });
});
