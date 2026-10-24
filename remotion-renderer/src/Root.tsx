import React from 'react';
import {
  AbsoluteFill,
  Composition,
  interpolate,
  useCurrentFrame,
} from 'remotion';

const HoniIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const titleOpacity = interpolate(frame, [0, 15, 120, 150], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const accentScale = interpolate(frame, [0, 150], [0.85, 1.15], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        backgroundColor: '#100d1d',
        color: '#f7f4ff',
        fontFamily: 'Arial, sans-serif',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          backgroundColor: '#ff4f9a',
          borderRadius: 999,
          height: 860,
          opacity: 0.35,
          position: 'absolute',
          transform: `scale(${accentScale})`,
          width: 860,
        }}
      />
      <div style={{opacity: titleOpacity, padding: 96, textAlign: 'center', zIndex: 1}}>
        <div style={{fontSize: 54, fontWeight: 700, letterSpacing: 10}}>HONI NEWS</div>
        <div style={{fontSize: 32, marginTop: 32}}>Remotion is ready to render.</div>
      </div>
    </AbsoluteFill>
  );
};

export const RemotionRoot: React.FC = () => (
  <Composition
    id="HoniIntro"
    component={HoniIntro}
    durationInFrames={150}
    fps={30}
    height={1920}
    width={1080}
  />
);
