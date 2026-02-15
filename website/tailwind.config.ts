import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        display: ['var(--font-jetbrains-mono)'],
        body: ['var(--font-dm-sans)'],
      },
      animation: {
        bob: 'bob 8s ease-in-out infinite',
        'puff-1': 'puff-1 35s ease-in-out infinite',
        'puff-2': 'puff-2 42s ease-in-out infinite',
        'puff-3': 'puff-3 38s ease-in-out infinite',
        'puff-4': 'puff-4 30s ease-in-out infinite',
        'puff-5': 'puff-5 45s ease-in-out infinite',
        'puff-6': 'puff-6 33s ease-in-out infinite',
        'puff-7': 'puff-7 40s ease-in-out infinite',
        'puff-8': 'puff-8 28s ease-in-out infinite',
        'puff-9': 'puff-9 37s ease-in-out infinite',
      },
      keyframes: {
        bob: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-8px)' },
        },
        'puff-1': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '33%': { transform: 'translate(120px, 60px) scale(1.08)' },
          '66%': { transform: 'translate(-80px, -40px) scale(0.95)' },
        },
        'puff-2': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '50%': { transform: 'translate(-100px, 80px) scale(1.1)' },
        },
        'puff-3': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '25%': { transform: 'translate(60px, -50px) scale(1.05)' },
          '75%': { transform: 'translate(-90px, 30px) scale(0.97)' },
        },
        'puff-4': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '33%': { transform: 'translate(-70px, -60px) scale(1.06)' },
          '66%': { transform: 'translate(100px, 40px) scale(0.94)' },
        },
        'puff-5': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '50%': { transform: 'translate(80px, -70px) scale(1.08)' },
        },
        'puff-6': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '40%': { transform: 'translate(-60px, 50px) scale(1.05)' },
          '80%': { transform: 'translate(90px, -30px) scale(0.96)' },
        },
        'puff-7': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '33%': { transform: 'translate(70px, 80px) scale(1.07)' },
          '66%': { transform: 'translate(-110px, -20px) scale(0.95)' },
        },
        'puff-8': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '50%': { transform: 'translate(-80px, 60px) scale(1.1)' },
        },
        'puff-9': {
          '0%, 100%': { transform: 'translate(0, 0) scale(1)' },
          '25%': { transform: 'translate(50px, -40px) scale(0.97)' },
          '75%': { transform: 'translate(-70px, 70px) scale(1.06)' },
        },
      },
    },
  },
  plugins: [],
};

export default config;
