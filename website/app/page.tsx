'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';

/* ─── Icons ─── */

function AppleIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="currentColor" viewBox="0 0 384 512">
      <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
    </svg>
  );
}

function XIcon({ className = 'w-4 h-4' }: { className?: string }) {
  return (
    <svg className={className} fill="currentColor" viewBox="0 0 24 24">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
  );
}

function GitHubIcon({ className = 'w-5 h-5' }: { className?: string }) {
  return (
    <svg className={className} fill="currentColor" viewBox="0 0 16 16">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}

/* ─── Variant C — Screenshot-Forward ─── */

export default function Home() {
  const [scrolled, setScrolled] = useState(false);
  const [syncState, setSyncState] = useState<'idle' | 'syncing' | 'done'>('idle');

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleSync = () => {
    if (syncState !== 'idle') return;
    setSyncState('syncing');
    setTimeout(() => setSyncState('done'), 1800);
    setTimeout(() => setSyncState('idle'), 3400);
  };

  return (
    <main className="relative h-screen overflow-hidden">
      {/* Drifting Clouds — individual puffs with their own animations */}
      <div className="cloud-layer cloud-layer-1" aria-hidden="true">
        <div className="cloud-puff w-[900px] h-[900px] bg-blue-300/60 blur-[150px] top-[-10%] left-[-10%] animate-puff-1" />
        <div className="cloud-puff w-[800px] h-[700px] bg-blue-200/45 blur-[140px] top-[5%] left-[30%] animate-puff-2" />
        <div className="cloud-puff w-[1000px] h-[800px] bg-sky-200/55 blur-[160px] top-[-5%] right-[-15%] animate-puff-3" />
      </div>
      <div className="cloud-layer cloud-layer-2" aria-hidden="true">
        <div className="cloud-puff w-[700px] h-[700px] bg-white/80 blur-[120px] top-[10%] left-[15%] animate-puff-4" />
        <div className="cloud-puff w-[800px] h-[600px] bg-blue-200/50 blur-[130px] top-[20%] right-[5%] animate-puff-5" />
        <div className="cloud-puff w-[600px] h-[600px] bg-sky-100/50 blur-[110px] top-[40%] left-[40%] animate-puff-6" />
      </div>
      <div className="cloud-layer cloud-layer-3" aria-hidden="true">
        <div className="cloud-puff w-[1000px] h-[600px] bg-white/70 blur-[140px] top-[30%] left-[-5%] animate-puff-7" />
        <div className="cloud-puff w-[900px] h-[700px] bg-sky-300/35 blur-[150px] top-[50%] right-[-10%] animate-puff-8" />
        <div className="cloud-puff w-[700px] h-[500px] bg-blue-100/50 blur-[120px] top-[60%] left-[25%] animate-puff-9" />
      </div>

      {/* Bottom fade to white */}
      <div className="fixed inset-0 pointer-events-none z-[3]" aria-hidden="true">
        <div className="absolute bottom-0 left-0 right-0 h-[30vh] bg-gradient-to-t from-white to-transparent" />
      </div>

      {/* Navigation */}
      <motion.nav
        className="fixed top-0 left-0 right-0 z-50"
        animate={{
          backdropFilter: scrolled ? 'blur(20px)' : 'blur(0px)',
          backgroundColor: scrolled ? 'rgba(255,255,255,0.7)' : 'rgba(255,255,255,0)',
          borderBottomWidth: scrolled ? '1px' : '0px',
          borderBottomColor: scrolled ? 'rgba(226,232,240,0.5)' : 'rgba(226,232,240,0)',
          boxShadow: scrolled ? '0 1px 3px rgba(0,0,0,0.05)' : '0 0 0 rgba(0,0,0,0)',
        }}
        transition={{ duration: 0.3 }}
      >
        <div className="mx-auto max-w-6xl px-6 py-5 flex items-center justify-between">
          <a href="/" className="font-display font-bold text-lg tracking-tight text-slate-900">
            Hypersync
          </a>
          <div className="flex items-center gap-5">
            <a
              href="https://x.com/mikiovsh"
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-400 hover:text-slate-600 transition-colors"
              aria-label="X"
            >
              <XIcon />
            </a>
            <a
              href="https://github.com/ovsh/hypersync"
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-400 hover:text-slate-600 transition-colors"
              aria-label="GitHub"
            >
              <GitHubIcon />
            </a>
            <a
              href="https://github.com/ovsh/hypersync/releases/latest"
              className="px-5 py-2 rounded-full bg-blue-500 text-white text-sm font-display font-medium hover:bg-blue-600 transition-all"
            >
              Download
            </a>
          </div>
        </div>
      </motion.nav>

      {/* Hero — Screenshot-Forward */}
      <section className="relative h-full flex items-center z-10">
        <div className="mx-auto max-w-7xl px-6 w-full">
          <div className="flex items-center gap-12 lg:gap-16">
            {/* Left — Text (narrower) */}
            <motion.div
              className="w-full md:w-[40%] shrink-0"
              initial="hidden"
              animate="visible"
              variants={{ hidden: {}, visible: { transition: { staggerChildren: 0.1 } } }}
            >
              <motion.div variants={{ hidden: { opacity: 0, y: 16 }, visible: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 80, damping: 20 } } }}>
                <div className="flex items-center gap-3 mb-6">
                  <img src="/app-icon.png" alt="Hypersync" className="w-10 h-10 rounded-xl shadow-md shadow-blue-200/50" />
                  <div className="flex items-center gap-2">
                    <span className="px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-slate-500 text-[11px] font-display font-medium">Open Source</span>
                    <span className="px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-slate-500 text-[11px] font-display font-medium">MIT License</span>
                    <span className="px-2.5 py-1 rounded-full bg-slate-50 border border-slate-200 text-slate-500 text-[11px] font-display font-medium">Free</span>
                  </div>
                </div>
              </motion.div>

              <motion.h1
                className="font-display font-extrabold text-4xl lg:text-5xl tracking-tight leading-[1.1] text-slate-900 mb-5"
                variants={{ hidden: { opacity: 0, y: 16 }, visible: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 80, damping: 20 } } }}
              >
                Keep your team&apos;s AI skills in sync
              </motion.h1>

              <motion.div
                className="space-y-2 mb-8"
                variants={{ hidden: { opacity: 0, y: 16 }, visible: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 80, damping: 20 } } }}
              >
                <p className="text-slate-500 text-lg leading-relaxed font-body">
                  Share skills and rules across your team in a click.
                </p>
                <p className="text-slate-500 text-lg leading-relaxed font-body">
                  Works across Cursor, Claude Code, Codex, and more.
                </p>
                <p className="text-slate-500 text-lg leading-relaxed font-body">
                  All from your GitHub repo. Fully open source.
                </p>
              </motion.div>

              <motion.div
                className="flex flex-wrap items-center gap-3 mb-8"
                variants={{ hidden: { opacity: 0, y: 16 }, visible: { opacity: 1, y: 0, transition: { type: 'spring' as const, stiffness: 80, damping: 20 } } }}
              >
                <a
                  href="https://github.com/ovsh/hypersync/releases/latest"
                  className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-b from-blue-400 to-blue-600 text-white font-display font-semibold text-sm shadow-[0_4px_20px_rgba(59,130,246,0.35)] hover:shadow-[0_8px_32px_rgba(59,130,246,0.45)] transition-all duration-300 hover:-translate-y-0.5"
                >
                  <AppleIcon className="w-4 h-4" />
                  Download for macOS
                </a>
                <a
                  href="https://github.com/ovsh/hypersync"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-slate-400 hover:text-slate-600 transition-colors text-sm font-body"
                >
                  View on GitHub
                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12h15m0 0l-6.75-6.75M19.5 12l-6.75 6.75" />
                  </svg>
                </a>
              </motion.div>

            </motion.div>

            {/* Right — Simulated Skills Browser */}
            <motion.div
              className="hidden md:block flex-1 min-w-0"
              initial={{ opacity: 0, x: 40, y: 20 }}
              animate={{ opacity: 1, x: 0, y: 0 }}
              transition={{ type: 'spring', stiffness: 40, damping: 18, delay: 0.25 }}
            >
              <div className="animate-bob -mr-12 lg:-mr-24 relative">
                {/* Menu bar popover — right-aligned, overlapping into skills browser */}
                <div className="absolute -top-4 right-[15%] z-10 rounded-2xl overflow-hidden shadow-2xl shadow-blue-300/20 border border-white/10 max-w-[260px]">
                  <div className="bg-[#1e1e22] p-3.5 space-y-2.5">
                    {/* App identity + status */}
                    <div className="flex items-center gap-2.5">
                      <img src="/app-icon.png" alt="" className="w-7 h-7 rounded-lg" />
                      <div className="text-white text-[13px] font-display font-semibold">Hypersync</div>
                      <div className="ml-auto flex items-center gap-1.5">
                        <div className={`w-1.5 h-1.5 rounded-full transition-colors duration-300 ${
                          syncState === 'syncing' ? 'bg-blue-400 animate-pulse' : 'bg-emerald-400'
                        }`} />
                        <span className="text-white/40 text-[10px] font-body">
                          {syncState === 'syncing' ? 'Syncing' : syncState === 'done' ? 'Synced' : '9:58 PM'}
                        </span>
                      </div>
                    </div>

                    {/* Sync Now button — interactive */}
                    <button
                      onClick={handleSync}
                      className={`w-full py-1.5 rounded-lg text-white text-[13px] font-display font-semibold flex items-center justify-center gap-2 shadow-md transition-all duration-300 cursor-pointer ${
                        syncState === 'done'
                          ? 'bg-gradient-to-b from-emerald-500 to-emerald-600 shadow-emerald-500/20'
                          : 'bg-gradient-to-b from-blue-500 to-blue-600 shadow-blue-500/20 hover:from-blue-400 hover:to-blue-500 active:scale-[0.97]'
                      }`}
                    >
                      {syncState === 'done' ? (
                        <>
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                          </svg>
                          Synced!
                        </>
                      ) : (
                        <>
                          <svg
                            className={`w-3.5 h-3.5 ${syncState === 'syncing' ? 'animate-spin' : ''}`}
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="2"
                            viewBox="0 0 24 24"
                          >
                            <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182M21.993 4.356v4.992" />
                          </svg>
                          {syncState === 'syncing' ? 'Syncing\u2026' : 'Sync Now'}
                        </>
                      )}
                    </button>
                  </div>
                </div>

                {/* Skills browser */}
                <div className="rounded-2xl overflow-hidden shadow-2xl shadow-blue-300/20 border border-white/10 mt-12">
                  {/* macOS title bar — dark */}
                  <div className="flex items-center px-4 py-3 bg-[#2a2a2e] border-b border-white/5">
                    <div className="flex gap-[7px]">
                      <div className="w-[11px] h-[11px] rounded-full bg-[#ff5f57]" />
                      <div className="w-[11px] h-[11px] rounded-full bg-[#febc2e]" />
                      <div className="w-[11px] h-[11px] rounded-full bg-[#28c840]" />
                    </div>
                    <span className="flex-1 text-center text-[13px] text-white/50 font-display font-medium pr-[46px]">
                      Skills
                    </span>
                  </div>

                  {/* Skills browser body */}
                  <div className="bg-[#1e1e22] p-4 space-y-3">
                    {/* Header */}
                    <div className="flex items-center gap-3 mb-1">
                      <img src="/app-icon.png" alt="" className="w-9 h-9 rounded-lg" />
                      <div>
                        <div className="text-white text-sm font-display font-semibold">Skills</div>
                        <div className="text-white/40 text-[11px] font-body">Installed skill definitions</div>
                      </div>
                      <div className="ml-auto px-2 py-0.5 rounded-md bg-blue-500/20 text-blue-400 text-[11px] font-display font-semibold">
                        12
                      </div>
                    </div>

                    {/* Tabs */}
                    <div className="flex rounded-lg bg-white/5 p-0.5 text-[11px] font-display">
                      <div className="flex-1 text-center py-1.5 text-white/40">Team <span className="text-white/25">3</span></div>
                      <div className="flex-1 text-center py-1.5 rounded-md bg-white/10 text-white font-medium">Local <span className="text-white/50">7</span></div>
                      <div className="flex-1 text-center py-1.5 text-white/40">Playground <span className="text-white/25">2</span></div>
                    </div>

                    {/* Skill cards */}
                    {[
                      { name: 'code-review', desc: 'Review pull requests for bugs, security issues, and style violations. Runs on every PR.' },
                      { name: 'interview', desc: 'Ask progressively deeper questions to clarify requirements before building. Surfaces blind spots.' },
                      { name: 'security-best-practices', desc: 'Language and framework specific security reviews. Suggests improvements on request.' },
                      { name: 'simplify', desc: 'Reduce complexity in code, writing, or processes. Cut the fluff, keep the function.' },
                      { name: 'write', desc: 'Polish and humanize written content. Removes AI voice, adds literary variety.' },
                    ].map((skill) => (
                      <div
                        key={skill.name}
                        className="rounded-lg bg-white/[0.04] border border-white/[0.06] p-3 hover:bg-white/[0.06] transition-colors"
                      >
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-white text-[13px] font-display font-semibold">{skill.name}</span>
                          <div className="flex items-center gap-1.5">
                            <div className="w-5 h-5 rounded-full flex items-center justify-center text-blue-400">
                              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                              </svg>
                            </div>
                          </div>
                        </div>
                        <p className="text-white/60 text-[11px] leading-relaxed font-body line-clamp-2">
                          {skill.desc}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Footer strip */}
      <div className="absolute bottom-0 left-0 right-0 z-20">
        <div className="mx-auto max-w-6xl px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-5">
            <a
              href="https://x.com/mikiovsh"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-slate-300 hover:text-slate-500 transition-colors text-xs font-body"
            >
              <XIcon className="w-3 h-3" />
              X
            </a>
            <a
              href="https://github.com/ovsh/hypersync"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-slate-300 hover:text-slate-500 transition-colors text-xs font-body"
            >
              <GitHubIcon className="w-3.5 h-3.5" />
              GitHub
            </a>
            <span className="text-slate-300 text-xs font-body">MIT License</span>
          </div>
          <span className="text-slate-300 text-xs font-body">Built with Next.js</span>
        </div>
      </div>
    </main>
  );
}
