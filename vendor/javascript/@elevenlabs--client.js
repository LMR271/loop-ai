/**
 * Bundled by jsDelivr using Rollup v4.62.2 and esbuild v0.28.1.
 * Original file: /npm/@elevenlabs/client@1.15.0/dist/platform/web/index.js
 *
 * Do NOT use SRI with dynamically generated files! More information: https://www.jsdelivr.com/using-sri-with-dynamic-files
 */
import{Track as S,Room as _e,RoomEvent as g,ConnectionState as ve,createLocalAudioTrack as ye}from"livekit-client";class X{queue=[];disconnectionDetails=null;onDisconnectCallback=null;onMessageCallback=null;onModeChangeCallback=null;onDebug;constructor(e={}){this.onDebug=e.onDebug}debug(e){this.onDebug&&this.onDebug(e)}onMessage(e){this.onMessageCallback=e;const t=this.queue;this.queue=[],t.length>0&&queueMicrotask(()=>{t.forEach(e)})}onDisconnect(e){this.onDisconnectCallback=e;const t=this.disconnectionDetails;t&&queueMicrotask(()=>{e(t)})}onModeChange(e){this.onModeChangeCallback=e}updateMode(e){this.onModeChangeCallback?.(e)}disconnect(e){this.disconnectionDetails||(this.disconnectionDetails=e,this.onDisconnectCallback?.(e))}handleMessage(e){this.onMessageCallback?this.onMessageCallback(e):this.queue.push(e)}}function M(o){const[e,t]=o.split("_");if(!["pcm","ulaw"].includes(e))throw new Error(`Invalid format: ${o}`);const n=Number.parseInt(t);if(Number.isNaN(n))throw new Error(`Invalid sample rate: ${t}`);return{format:e,sampleRate:n}}function R(o){return o!=null&&typeof o=="object"&&!Array.isArray(o)}function we(o,e="Expected a JSON object"){if(!R(o))throw new Error(e)}async function K(o){try{const e=await o.json();if(!R(e))return o.statusText||"Unknown error";const t=e.detail,n=R(t)?t.message:t;if(typeof n=="string")return n}catch(e){console.warn("Failed to parse API error response as JSON:",e)}return o.statusText||"Unknown error"}class U extends Error{closeCode;closeReason;constructor(e,t){super(e),this.name="SessionConnectionError",this.closeCode=t?.closeCode,this.closeReason=t?.closeReason}}const Se="1.15.0";let D=Object.freeze({name:"js_sdk",version:Se});function N(o){return!!o.type}const Z="conversation_initiation_client_data";function ee(o){const e={type:Z};return o.overrides&&(e.conversation_config_override={agent:{prompt:o.overrides.agent?.prompt,first_message:o.overrides.agent?.firstMessage,language:o.overrides.agent?.language},tts:{voice_id:o.overrides.tts?.voiceId,speed:o.overrides.tts?.speed,stability:o.overrides.tts?.stability,similarity_boost:o.overrides.tts?.similarityBoost},...o.overrides.asr?.keywords!==void 0?{asr:{keywords:o.overrides.asr.keywords}}:{},conversation:{text_only:o.overrides.conversation?.textOnly}}),o.customLlmExtraBody&&(e.custom_llm_extra_body=o.customLlmExtraBody),o.dynamicVariables&&(e.dynamic_variables=o.dynamicVariables),o.userId&&(e.user_id=o.userId),e.source_info={source:D.name,version:D.version},o.toolMockConfig&&(e.tool_mock_config={mocking_strategy:o.toolMockConfig.mockingStrategy,mocked_tool_names:o.toolMockConfig.mockedToolNames,fallback_strategy:o.toolMockConfig.fallbackStrategy}),e}function V(o){const e=new Uint8Array(o);return btoa(String.fromCharCode(...e))}function be(o){const e=atob(o),t=e.length,n=new Uint8Array(t);for(let i=0;i<t;i++)n[i]=e.charCodeAt(i);return n.buffer}const P={getVolume:()=>0,getByteFrequencyData:()=>{}},Ce=100,ke=8e3;function te(o,e,t){const n=o.length,i=t/2/n,s=Math.floor(Ce/i),r=Math.min(Math.ceil(ke/i),n),a=r-s,c=e.length;for(let u=0;u<c;u++){const d=u/c*a,h=s+Math.floor(d),p=Math.min(h+1,r-1),m=d-Math.floor(d);e[u]=Math.round(o[h]*(1-m)+o[p]*m)}}let ne;function Ee(o){ne=o}function Ae(){return ne?.()??null}const Te="wss://livekit.rtc.elevenlabs.io",Ie="https://api.elevenlabs.io",Me=.01;function Re(o){return o.replace(/^wss:\/\//,"https://")}class A extends X{conversationId;inputFormat;outputFormat;room;isConnected=!1;audioEventId=1;outputDeviceId=null;audioAdapter;inputAnalyser=void 0;inputVolumeProvider=P;outputAnalyser=void 0;outputVolumeProvider=P;_isMuted=!1;input={close:async()=>{if(this.isConnected)try{this.room.localParticipant.audioTrackPublications.forEach(e=>{e.track&&e.track.stop()})}catch(e){console.warn("Error stopping local tracks:",e)}},setDevice:async e=>{if(e?.sampleRate!==void 0||e?.format!==void 0||e?.preferHeadphonesForIosDevices!==void 0)throw new Error("WebRTC input device does not support sampleRate, format, or preferHeadphonesForIosDevices options");const t=e?.inputDeviceId;t&&await this.setAudioInputDevice(t)},setMuted:async e=>{if(!this.isConnected||!this.room.localParticipant){console.warn("Cannot set microphone muted: room not connected or no local participant");return}this._isMuted=e;const t=this.room.localParticipant.getTrackPublication(S.Source.Microphone);if(t?.track)try{e?await t.track.mute():await t.track.unmute()}catch{await this.room.localParticipant.setMicrophoneEnabled(!e)}else await this.room.localParticipant.setMicrophoneEnabled(!e);if(!e){const n=this.room.localParticipant.getTrackPublication(S.Source.Microphone)?.track;n&&this.setupInputAnalyser(n.mediaStreamTrack)}},isMuted:()=>this._isMuted,getAnalyser:()=>this.inputAnalyser,getVolume:()=>this._isMuted?0:this.inputVolumeProvider.getVolume(),getByteFrequencyData:e=>{if(this._isMuted){e.fill(0);return}this.inputVolumeProvider.getByteFrequencyData(e)}};output={close:async()=>{},setDevice:async e=>{if(e?.sampleRate!==void 0||e?.format!==void 0)throw new Error("WebRTC output device does not support sampleRate or format options");const t=e?.outputDeviceId;t&&await this.setAudioOutputDevice(t)},setVolume:e=>{this.setAudioVolume(e)},interrupt:e=>{},getAnalyser:()=>this.outputAnalyser,getVolume:()=>this.outputVolumeProvider.getVolume(),getByteFrequencyData:e=>{this.outputVolumeProvider.getByteFrequencyData(e)}};constructor(e,t,n,i,s={}){super(s),this.room=e,this.conversationId=t,this.inputFormat=n,this.outputFormat=i,this.audioAdapter=Ae(),this.setupRoomEventListeners()}static async create(e){let t;if("conversationToken"in e&&e.conversationToken)t=e.conversationToken;else if("agentId"in e&&e.agentId)try{const{name:i,version:s}=D,r=e.origin??Ie;let c=`${Re(r)}/v1/convai/conversation/token?agent_id=${e.agentId}&source=${i}&version=${s}`;e.environment&&(c+=`&environment=${encodeURIComponent(e.environment)}`);const u=await fetch(c);if(!u.ok){const h=await K(u);throw new Error(`ElevenLabs API returned ${u.status} ${h}`)}const d=await u.json();if(!R(d)||typeof d.token!="string")throw new Error("No conversation token received from API");if(t=d.token,!t)throw new Error("No conversation token received from API")}catch(i){let s=i instanceof Error?i.message:String(i);throw i instanceof Error&&i.message.includes("401")&&(s="Your agent has authentication enabled, but no signed URL or conversation token was provided."),new Error(`Failed to fetch conversation token for agent ${e.agentId}: ${s}`)}else throw new Error("Either conversationToken or agentId is required for WebRTC connection");const n=new _e({singlePeerConnection:!1});try{const i=`room_${Date.now()}`,s=M("pcm_48000"),r=M("pcm_48000"),a=new A(n,i,s,r,e),c=e.livekitUrl||Te,u=e.textOnly?Promise.resolve():new Promise((p,m)=>{n.once(g.SignalConnected,()=>{n.localParticipant.setMicrophoneEnabled(!0).then(()=>p()).catch(m)})});await n.connect(c,t),await new Promise(p=>{if(a.isConnected)p();else{const m=()=>{n.off(g.Connected,m),p()};n.on(g.Connected,m)}}),await u;const d=n.localParticipant.getTrackPublication(S.Source.Microphone)?.track;d&&a.setupInputAnalyser(d.mediaStreamTrack),n.name&&(a.conversationId=n.name.match(/(conv_[a-zA-Z0-9]+)/)?.[0]||n.name);const h=ee(e);return a.debug({type:Z,message:h}),await a.sendMessage(h),a}catch(i){throw await n.disconnect(),i}}setupRoomEventListeners(){this.room.on(g.Connected,()=>{this.isConnected=!0}),this.room.on(g.Disconnected,e=>{this.isConnected=!1,this.disconnect({reason:"agent",context:{type:"close",reason:e?.toString()}})}),this.room.on(g.ConnectionStateChanged,e=>{e===ve.Disconnected&&(this.isConnected=!1,this.disconnect({reason:"error",message:`LiveKit connection state changed to ${e}`,context:{type:"connection_state_changed"}}))}),this.room.on(g.DataReceived,(e,t)=>{try{const n=JSON.parse(new TextDecoder().decode(e));if(n.type==="audio")return;N(n)?this.handleMessage(n):console.warn("Invalid socket event received:",n)}catch(n){console.warn("Failed to parse incoming data message:",n),console.warn("Raw payload:",new TextDecoder().decode(e))}}),this.room.on(g.TrackSubscribed,async(e,t,n)=>{if(e.kind===S.Kind.Audio&&n.identity.includes("agent")){const i=e;this.audioAdapter&&(await this.audioAdapter.attachRemoteTrack(i,this.outputDeviceId),await this.setupAudioCapture(i),this.onDebug?.({type:"audio_element_ready"}))}}),this.room.on(g.ActiveSpeakersChanged,async e=>{e.length>0?this.updateMode(e[0].identity.startsWith("agent")?"speaking":"listening"):this.updateMode("listening")}),this.room.on(g.ParticipantDisconnected,e=>{e.identity?.startsWith("agent")&&this.disconnect({reason:"agent",context:{type:"close",reason:"agent disconnected"}})})}close(){if(this.isConnected){try{this.room.localParticipant.audioTrackPublications.forEach(e=>{e.track&&e.track.stop()})}catch(e){console.warn("Error stopping local tracks:",e)}this.audioAdapter?.cleanup(),this.inputAnalyser=void 0,this.outputAnalyser=void 0,this.inputVolumeProvider=P,this.outputVolumeProvider=P,this.room.disconnect()}}async sendMessage(e){if(!this.isConnected||!this.room.localParticipant){console.warn("Cannot send message: room not connected or no local participant");return}if(!("user_audio_chunk"in e))try{const n=new TextEncoder().encode(JSON.stringify(e));await this.room.localParticipant.publishData(n,{reliable:!0})}catch(t){this.debug({type:"send_message_error",message:{message:e,error:t}}),console.error("Failed to send message via WebRTC:",t)}}getRoom(){return this.room}setupInputAnalyser(e){if(this.audioAdapter)try{const t=this.audioAdapter.setupInputAnalysis(e);this.inputVolumeProvider=t.volumeProvider,this.inputAnalyser=t.analyser}catch(t){console.warn("[ConversationalAI] Failed to set up input volume analyser:",t)}}setInputVolumeProvider(e){this.inputVolumeProvider=e}setOutputVolumeProvider(e){this.outputVolumeProvider=e}async setupAudioCapture(e){if(this.audioAdapter)try{const t=(i,s)=>{if(s>Me){const r=V(i),a=this.audioEventId++;this.handleMessage({type:"audio",audio_event:{audio_base_64:r,event_id:a}})}},n=await this.audioAdapter.setupOutputAnalysis(e,this.outputFormat,t);this.outputVolumeProvider=n.volumeProvider,this.outputAnalyser=n.analyser}catch(t){console.warn("Failed to set up audio capture:",t)}}setAudioVolume(e){this.audioAdapter?.setVolume(e)}async setAudioOutputDevice(e){if(!this.audioAdapter)throw new Error("Cannot set output device: no audio adapter available on this platform");await this.audioAdapter.setOutputDevice(e),this.outputDeviceId=e}async setAudioInputDevice(e){if(!this.isConnected||!this.room.localParticipant)throw new Error("Cannot change input device: room not connected or no local participant");try{const t=this.room.localParticipant.getTrackPublication(S.Source.Microphone);t?.track&&(await t.track.stop(),await this.room.localParticipant.unpublishTrack(t.track));const n=await ye({deviceId:{exact:e},echoCancellation:!0,noiseSuppression:!0,autoGainControl:!0,channelCount:{ideal:1}});await this.room.localParticipant.publishTrack(n,{name:"microphone",source:S.Source.Microphone}),this.setupInputAnalyser(n.mediaStreamTrack)}catch(t){console.error("Failed to change input device:",t);try{await this.room.localParticipant.setMicrophoneEnabled(!0)}catch(n){console.error("Failed to recover microphone after device switch error:",n)}throw t}}}let W;function De(o){W=o}function Pe(o){if(!(o instanceof A))throw new Error(`setupWebRTCSession requires a WebRTCConnection. Received: ${o?.constructor?.name??typeof o}`);return{connection:o,input:o.input,output:o.output,playbackEventTarget:null,detach:async()=>{}}}const x=new Map;function B(o,e){return async(t,n)=>{const i=x.get(o);if(i)return t.addModule(i);if(n)try{await t.addModule(n),x.set(o,n);return}catch(a){throw new Error(`Failed to load the ${o} worklet module from path: ${n}. Error: ${a}`)}const s=new Blob([e],{type:"application/javascript"}),r=URL.createObjectURL(s);try{await t.addModule(r),x.set(o,r);return}catch{URL.revokeObjectURL(r)}try{const c=`data:application/javascript;base64,${btoa(e)}`;await t.addModule(c),x.set(o,c)}catch{throw new Error(`Failed to load the ${o} worklet module. Make sure the browser supports AudioWorklets. If you are using a strict CSP, you may need to self-host the worklet files.`)}}}const xe=B("audioConcatProcessor",`/*
 * ulaw decoding logic taken from the wavefile library
 * https://github.com/rochars/wavefile/blob/master/lib/codecs/mulaw.js
 * USED BY @elevenlabs/client
 */

const decodeTable = [0, 132, 396, 924, 1980, 4092, 8316, 16764];

function decodeSample(muLawSample) {
  let sign;
  let exponent;
  let mantissa;
  let sample;
  muLawSample = ~muLawSample;
  sign = muLawSample & 0x80;
  exponent = (muLawSample >> 4) & 0x07;
  mantissa = muLawSample & 0x0f;
  sample = decodeTable[exponent] + (mantissa << (exponent + 3));
  if (sign !== 0) sample = -sample;

  return sample;
}

class AudioConcatProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.buffers = []; // Initialize an empty buffer
    this.cursor = 0;
    this.currentBuffer = null;
    this.wasInterrupted = false;
    this.finished = false;

    this.port.onmessage = ({ data }) => {
      switch (data.type) {
        case "setFormat":
          this.format = data.format;
          if (globalThis.LibSampleRate && sampleRate !== data.sampleRate) {
            globalThis.LibSampleRate.create(
              1,
              data.sampleRate,
              sampleRate
            ).then(resampler => {
              this.resampler = resampler;
            });
          }
          break;
        case "buffer":
          this.wasInterrupted = false;
          this.buffers.push(
            this.format === "ulaw"
              ? new Uint8Array(data.buffer)
              : new Int16Array(data.buffer)
          );
          break;
        case "interrupt":
          this.wasInterrupted = true;
          break;
        case "clearInterrupted":
          if (this.wasInterrupted) {
            this.wasInterrupted = false;
            this.buffers = [];
            this.currentBuffer = null;
          }
      }
    };
  }
  process(_, outputs) {
    let finished = false;
    const output = outputs[0][0];
    for (let i = 0; i < output.length; i++) {
      if (!this.currentBuffer) {
        if (this.buffers.length === 0) {
          finished = true;
          break;
        }
        this.currentBuffer = this.buffers.shift();
        if (this.resampler) {
          this.currentBuffer = this.resampler.full(this.currentBuffer);
        }
        this.cursor = 0;
      }

      let value = this.currentBuffer[this.cursor];
      if (this.format === "ulaw") {
        value = decodeSample(value);
      }
      output[i] = value / 32768;
      this.cursor++;

      if (this.cursor >= this.currentBuffer.length) {
        this.currentBuffer = null;
      }
    }

    if (this.finished !== finished) {
      this.finished = finished;
      this.port.postMessage({ type: "process", finished });
    }

    return true; // Continue processing
  }
}

registerProcessor("audioConcatProcessor", AudioConcatProcessor);
`),Fe="https://cdn.jsdelivr.net/npm/@alexanderolsen/libsamplerate-js@2.1.2/dist/libsamplerate.worklet.js";async function oe(o,e){const t=e||Fe;await o.audioWorklet.addModule(t)}function Oe(o){if(o.length===0)return 0;let e=0;for(let t=0;t<o.length;t++)e+=o[t]/255;return e/=o.length,e<0?0:e>1?1:e}function F(o,e){const t=o.frequencyBinCount;let n,i;return{getVolume(){return n??=new Uint8Array(t),i??=new Uint8Array(t),o.getByteFrequencyData(n),te(n,i,e),Oe(i)},getByteFrequencyData(s){n??=new Uint8Array(t),o.getByteFrequencyData(n),te(n,s,e)}}}function b(){return["iPad Simulator","iPhone Simulator","iPod Simulator","iPad","iPhone","iPod"].includes(navigator.platform)||navigator.userAgent.includes("Mac")&&"ontouchend"in document}function Le(){return/android/i.test(navigator.userAgent)}function Ue({sampleRate:o,format:e,worklet:t,audioElement:n}){if(!b())return;const s=Math.floor(o*100/1e3),r=e==="ulaw"?new Uint8Array(s).fill(255):new Int16Array(s);t.port.postMessage({type:"buffer",buffer:r.buffer}),n.play().catch(()=>{})}class J{context;analyser;gain;worklet;audioElement;static async create({sampleRate:e,format:t,outputDeviceId:n,workletPaths:i,libsampleratePath:s,audioContext:r}){let a=r??null,c=null;try{const u=navigator.mediaDevices.getSupportedConstraints().sampleRate;a||(a=new AudioContext(u?{sampleRate:e}:{}));const d=a.createAnalyser(),h=a.createGain();c=new Audio,c.src="",c.load(),c.autoplay=!0,c.style.display="none",document.body.appendChild(c);const p=a.createMediaStreamDestination();c.srcObject=p.stream,h.connect(d),d.connect(p),(!u||a.sampleRate!==e)&&(a.sampleRate!==e&&console.warn(`[ConversationalAI] Sample rate ${e} not available, resampling to ${a.sampleRate}`),await oe(a,s)),await xe(a.audioWorklet,i?.audioConcatProcessor);const m=new AudioWorkletNode(a,"audioConcatProcessor");return m.port.postMessage({type:"setFormat",format:t,sampleRate:e}),m.connect(h),await a.resume(),Ue({sampleRate:e,format:t,worklet:m,audioElement:c}),n&&c.setSinkId&&await c.setSinkId(n),new J(a,d,h,m,c)}catch(u){throw c?.parentNode&&c.parentNode.removeChild(c),c?.pause(),a&&a.state!=="closed"&&await a.close(),u}}volume=1;interrupted=!1;interruptTimeout=null;volumeProvider;constructor(e,t,n,i,s){this.context=e,this.analyser=t,this.gain=n,this.worklet=i,this.audioElement=s,this.worklet.port.start(),this.volumeProvider=F(t,e.sampleRate)}getAnalyser(){return this.analyser}getVolume(){return this.volumeProvider.getVolume()}getByteFrequencyData(e){this.volumeProvider.getByteFrequencyData(e)}addListener(e){this.worklet.port.addEventListener("message",e)}removeListener(e){this.worklet.port.removeEventListener("message",e)}setVolume(e){this.volume=e,this.gain.gain.value=e}playAudio(e){this.gain.gain.cancelScheduledValues(this.context.currentTime),this.gain.gain.value=this.volume,this.interruptTimeout&&(clearTimeout(this.interruptTimeout),this.interruptTimeout=null),this.worklet.port.postMessage({type:"clearInterrupted"}),this.worklet.port.postMessage({type:"buffer",buffer:e})}interrupt(e=2e3){this.interrupted=!0,this.interruptTimeout&&(clearTimeout(this.interruptTimeout),this.interruptTimeout=null),this.worklet.port.postMessage({type:"interrupt"}),this.gain.gain.exponentialRampToValueAtTime(1e-4,this.context.currentTime+e/1e3),this.interruptTimeout=setTimeout(()=>{this.interrupted=!1,this.gain.gain.value=this.volume,this.worklet.port.postMessage({type:"clearInterrupted"}),this.interruptTimeout=null},e)}async setDevice(e){if(!("setSinkId"in HTMLAudioElement.prototype))throw new Error("setSinkId is not supported in this browser");const t=e?.outputDeviceId;await this.audioElement.setSinkId(t||"")}async close(){this.interruptTimeout&&(clearTimeout(this.interruptTimeout),this.interruptTimeout=null),this.audioElement.parentNode&&this.audioElement.parentNode.removeChild(this.audioElement),this.audioElement.pause(),await this.context.close()}}const ie=B("rawAudioProcessor",`/*
 * ulaw encoding logic taken from the wavefile library
 * https://github.com/rochars/wavefile/blob/master/lib/codecs/mulaw.js
 * USED BY @elevenlabs/client
 */

const BIAS = 0x84;
const CLIP = 32635;
const encodeTable = [
  0,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,
  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
];

function encodeSample(sample) {
  let sign;
  let exponent;
  let mantissa;
  let muLawSample;
  sign = (sample >> 8) & 0x80;
  if (sign !== 0) sample = -sample;
  sample = sample + BIAS;
  if (sample > CLIP) sample = CLIP;
  exponent = encodeTable[(sample>>7) & 0xFF];
  mantissa = (sample >> (exponent+3)) & 0x0F;
  muLawSample = ~(sign | (exponent << 4) | mantissa);
  
  return muLawSample;
}

class RawAudioProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
              
    this.port.onmessage = ({ data }) => {
      switch (data.type) {
        case "setFormat":
          this.isMuted = false;
          this.buffer = []; // Initialize an empty buffer
          const chunkDurationMs = data.chunkDurationMs ?? 25;
          this.bufferSize = Math.max(
            1,
            Math.round((data.sampleRate * chunkDurationMs) / 1000)
          );
          this.format = data.format;

          if (globalThis.LibSampleRate && sampleRate !== data.sampleRate) {
            globalThis.LibSampleRate.create(1, sampleRate, data.sampleRate).then(resampler => {
              this.resampler = resampler;
            });
          }
          break;
        case "setMuted":
          this.isMuted = data.isMuted;
          break;
      }
    };
  }
  process(inputs) {
    if (!this.buffer) {
      return true;
    }
    
    const input = inputs[0]; // Get the first input node
    if (input.length > 0) {
      let channelData = input[0]; // Get the first channel's data

      // Resample the audio if necessary
      if (this.resampler) {
        channelData = this.resampler.full(channelData);
      }

      // Add channel data to the buffer
      this.buffer.push(...channelData);
      // Get max volume 
      let sum = 0.0;
      for (let i = 0; i < channelData.length; i++) {
        sum += channelData[i] * channelData[i];
      }
      const maxVolume = Math.sqrt(sum / channelData.length);
      // Check if buffer size has reached or exceeded the threshold
      if (this.buffer.length >= this.bufferSize) {
        const float32Array = this.isMuted 
          ? new Float32Array(this.buffer.length)
          : new Float32Array(this.buffer);

        let encodedArray = this.format === "ulaw"
          ? new Uint8Array(float32Array.length)
          : new Int16Array(float32Array.length);

        // Iterate through the Float32Array and convert each sample to PCM16
        for (let i = 0; i < float32Array.length; i++) {
          // Clamp the value to the range [-1, 1]
          let sample = Math.max(-1, Math.min(1, float32Array[i]));

          // Scale the sample to the range [-32768, 32767]
          let value = sample < 0 ? sample * 32768 : sample * 32767;
          if (this.format === "ulaw") {
            value = encodeSample(Math.round(value));
          }

          encodedArray[i] = value;
        }

        // Send the buffered data to the main script
        this.port.postMessage([encodedArray, maxVolume]);

        // Clear the buffer after sending
        this.buffer = [];
      }
    }
    return true; // Continue processing
  }
}
registerProcessor("rawAudioProcessor", RawAudioProcessor);
`),se=25,ae={echoCancellation:!0,noiseSuppression:!0,autoGainControl:!0,channelCount:{ideal:1}};class T{context;analyser;worklet;inputStream;mediaStreamSource;permissions;onError;static async create({sampleRate:e,format:t,preferHeadphonesForIosDevices:n,inputDeviceId:i,workletPaths:s,libsampleratePath:r,onError:a,inputChunkDurationMs:c=se}){let u=null,d=null;try{const h={sampleRate:{ideal:e},...ae};if(b()&&n){const Y=(await window.navigator.mediaDevices.enumerateDevices()).find(Q=>Q.kind==="audioinput"&&["airpod","headphone","earphone"].find(ge=>Q.label.toLowerCase().includes(ge)));Y&&(h.deviceId={ideal:Y.deviceId})}i&&(h.deviceId=T.getDeviceIdConstraint(i));const p=navigator.mediaDevices.getSupportedConstraints().sampleRate;u=new window.AudioContext(p?{sampleRate:e}:{});const m=u.createAnalyser();p||await oe(u,r),await ie(u.audioWorklet,s?.rawAudioProcessor);const w={voiceIsolation:!0,...h};d=await navigator.mediaDevices.getUserMedia({audio:w});const E=u.createMediaStreamSource(d),f=new AudioWorkletNode(u,"rawAudioProcessor");f.port.postMessage({type:"setFormat",format:t,sampleRate:e,chunkDurationMs:c}),E.connect(m),m.connect(f),await u.resume();const _=await navigator.permissions.query({name:"microphone"});return new T(u,m,f,d,E,_,a)}catch(h){throw d?.getTracks().forEach(p=>{p.stop()}),u?.close(),h}}static getDeviceIdConstraint(e){if(e)return b()?{ideal:e}:{exact:e}}muted=!1;volumeProvider;constructor(e,t,n,i,s,r,a=console.error){this.context=e,this.analyser=t,this.worklet=n,this.inputStream=i,this.mediaStreamSource=s,this.permissions=r,this.onError=a,this.permissions.addEventListener("change",this.handlePermissionsChange),this.worklet.port.start(),this.volumeProvider=F(t,e.sampleRate)}getAnalyser(){return this.analyser}getVolume(){return this.muted?0:this.volumeProvider.getVolume()}getByteFrequencyData(e){if(this.muted){e.fill(0);return}this.volumeProvider.getByteFrequencyData(e)}isMuted(){return this.muted}addListener(e){this.worklet.port.addEventListener("message",e)}removeListener(e){this.worklet.port.removeEventListener("message",e)}forgetInputStreamAndSource(){for(const e of this.inputStream.getTracks())e.stop();this.mediaStreamSource.disconnect()}async close(){this.forgetInputStreamAndSource(),this.permissions.removeEventListener("change",this.handlePermissionsChange),await this.context.close()}async setMuted(e){this.muted=e,this.worklet.port.postMessage({type:"setMuted",isMuted:e})}settingInput=!1;async setDevice(e){try{if(this.settingInput)throw new Error("Input device is already being set");this.settingInput=!0;const t=e?.inputDeviceId,n={...ae};t&&(n.deviceId=T.getDeviceIdConstraint(t));const i={voiceIsolation:!0,...n},s=await navigator.mediaDevices.getUserMedia({audio:i});this.forgetInputStreamAndSource(),this.inputStream=s,this.mediaStreamSource=this.context.createMediaStreamSource(s),this.mediaStreamSource.connect(this.analyser)}catch(t){throw this.onError("Failed to switch input device:",t),t}finally{this.settingInput=!1}}handlePermissionsChange=()=>{if(this.permissions.state==="denied")this.onError("Microphone permission denied");else if(!this.settingInput){const[e]=this.inputStream.getAudioTracks(),{deviceId:t}=e?.getSettings()??{};this.setDevice({inputDeviceId:t}).catch(n=>{this.onError("Failed to reset input device after permission change:",n)})}}}const Ne="convai",Ve="wss://api.elevenlabs.io",We="/v1/convai/conversation?agent_id=";class I extends X{socket;conversationId;inputFormat;outputFormat;outputListeners=new Set;pendingAudioEvents=[];constructor(e,t,n,i){super(),this.socket=e,this.conversationId=t,this.inputFormat=n,this.outputFormat=i,this.socket.addEventListener("error",s=>{setTimeout(()=>this.disconnect({reason:"error",message:"The connection was closed due to a socket error.",context:{type:s.type}}),0)}),this.socket.addEventListener("close",s=>{const r=s.code,a=s.reason||void 0,c={type:s.type,code:r,reason:a};this.disconnect(r===1e3?{reason:"agent",context:c,closeCode:r,closeReason:a}:{reason:"error",message:a||"The connection was closed by the server.",context:c,closeCode:r,closeReason:a})}),this.socket.addEventListener("message",s=>{try{const r=JSON.parse(s.data);if(!N(r)){this.debug({type:"invalid_event",message:"Received invalid socket event",data:s.data});return}this.handleMessage(r)}catch(r){this.debug({type:"parsing_error",message:"Failed to parse socket message",error:r instanceof Error?r.message:String(r),data:s.data})}})}static async create(e){let t=null;try{const n=e.origin??Ve;let i;const{name:s,version:r}=D;if(e.signedUrl){const w=e.signedUrl.includes("?")?"&":"?";i=`${e.signedUrl}${w}source=${s}&version=${r}`}else i=`${n}${We}${e.agentId}&source=${s}&version=${r}`;e.environment&&(i+=`&environment=${encodeURIComponent(e.environment)}`);const a=[Ne];e.authorization&&a.push(`bearer.${e.authorization}`),t=new WebSocket(i,a);const c=await new Promise((w,E)=>{t.addEventListener("open",()=>{const f=ee(e);t?.send(JSON.stringify(f))},{once:!0}),t.addEventListener("error",f=>{setTimeout(()=>E(new U("The connection was closed due to a socket error.")),0)}),t.addEventListener("close",f=>{const _=f.reason||(f.code===1e3?"Connection closed normally before session could be established.":"Connection closed unexpectedly before session could be established.");E(new U(_,{closeCode:f.code,closeReason:f.reason||void 0}))}),t.addEventListener("message",f=>{const _=JSON.parse(f.data);N(_)&&(_.type==="conversation_initiation_metadata"?w(_.conversation_initiation_metadata_event):console.warn("First received message is not conversation metadata."))},{once:!0})}),{conversation_id:u,agent_output_audio_format:d,user_input_audio_format:h}=c,p=M(h??"pcm_16000"),m=M(d);return new I(t,u,p,m)}catch(n){throw t?.close(),n}}close(){this.pendingAudioEvents=[],this.socket.close(1e3,"User ended conversation")}sendMessage(e){this.socket.send(JSON.stringify(e))}addListener(e){const t=this.outputListeners.size>0;if(this.outputListeners.add(e),t||this.pendingAudioEvents.length===0)return;const n=this.pendingAudioEvents;this.pendingAudioEvents=[];for(const i of n)e(i)}removeListener(e){this.outputListeners.delete(e)}handleMessage(e){if(super.handleMessage(e),e.type==="audio"&&e.audio_event.audio_base_64){const t={audio_base_64:e.audio_event.audio_base_64};if(this.outputListeners.size===0){this.pendingAudioEvents.push(t);return}this.outputListeners.forEach(n=>n(t))}}}function Be(o,e){const t=n=>{const i=n.data[0];e.sendMessage({user_audio_chunk:V(i.buffer)})};return o.addListener(t),()=>{o.removeListener(t)}}function $e(o,e){const t=n=>{e.playAudio(be(n.audio_base_64))};return o.addListener(t),()=>{o.removeListener(t)}}function qe(o){const e="signedUrl"in o&&o.signedUrl;if(e&&o.connectionType==="webrtc")throw new Error("signedUrl only supports websocket connections. Remove connectionType or set it to 'websocket'.");return o.connectionType?o.connectionType:"conversationToken"in o&&o.conversationToken?"webrtc":e||o.textOnly?"websocket":"webrtc"}async function $(o){const e=qe(o);switch(e){case"websocket":return I.create(o);case"webrtc":return A.create(o);default:throw new Error(`Unknown connection type: ${e}`)}}const He={default:0,android:3e3};function re(o,e="default"){const t=o??He;return e==="android"?t.android??t.default:e==="ios"?t.ios??t.default:t.default}async function ce(o){o>0&&await new Promise(e=>setTimeout(e,o))}const je=3e4,Ge=["touchstart","touchend","click"];let v=null,y=null,ue=!1;function ze(o){const e=o.createBuffer(1,1,22050),t=o.createBufferSource();t.buffer=e,t.connect(o.destination),t.start(0),o.resume().catch(()=>{})}function Je(){y&&clearTimeout(y),y=setTimeout(()=>{y=null,q()},je)}function le(){y&&(clearTimeout(y),y=null)}function Ye(){if(!b()||v)return;const o=new AudioContext;ze(o),v=o,Je()}function Qe(){if(!b()||ue||typeof document>"u")return;ue=!0;const o=()=>{Ye()};for(const e of Ge)document.addEventListener(e,o,!0)}function Xe(){const o=v;return v=null,le(),o}function q(){v&&(v.close().catch(()=>{}),v=null,le())}function Ke(){return Le()?"android":b()?"ios":"default"}async function de(){if("wakeLock"in navigator)try{return await navigator.wakeLock.request("screen")}catch{}return null}async function Ze(o,e,t){const[n,i]=await Promise.all([T.create({...e.inputFormat,preferHeadphonesForIosDevices:o.preferHeadphonesForIosDevices,inputDeviceId:o.inputDeviceId,inputChunkDurationMs:o.inputChunkDurationMs,workletPaths:o.workletPaths,libsampleratePath:o.libsampleratePath}),J.create({...e.outputFormat,outputDeviceId:o.outputDeviceId,workletPaths:o.workletPaths,audioContext:t??void 0})]),s=Be(n,e),r=$e(e,i);return{input:n,output:i,playbackEventTarget:i,detach:async()=>{s(),r()}}}async function et(o){const e=o.useWakeLock??!0;let t=null,n=null,i=null;try{e&&(t=await de()),n=await navigator.mediaDevices.getUserMedia({audio:!0});const s=Ke();await ce(re(o.connectionDelay,s));const r=await $(o);let a;try{r instanceof I?(i=Xe(),a={connection:r,...await Ze(o,r,i)},i=null):(q(),a=Pe(r))}catch(d){throw await i?.close().catch(()=>{}),i=null,r.close(),d}if(n){for(const d of n.getTracks())d.stop();n=null}let c=null;t&&(c=()=>{document.visibilityState==="visible"&&t?.released&&de().then(d=>{t=d})},document.addEventListener("visibilitychange",c));const u=a.detach;return{...a,detach:async()=>{await u(),c&&document.removeEventListener("visibilitychange",c);try{await t?.release(),t=null}catch{}}}}catch(s){if(n)for(const r of n.getTracks())r.stop();try{await t?.release(),t=null}catch{}throw q(),s}}De(et);class tt{audioElements=[];inputAudioContext=null;audioCaptureContext=null;async attachRemoteTrack(e,t){const n=e.attach();if(n.autoplay=!0,n.controls=!1,t&&n.setSinkId)try{await n.setSinkId(t)}catch(i){console.warn("Failed to set output device for new audio element:",i)}n.style.display="none",document.body.appendChild(n),this.audioElements.push(n)}setupInputAnalysis(e){this.inputAudioContext&&(this.inputAudioContext.close().catch(()=>{}),this.inputAudioContext=null);const t=new AudioContext,n=t.createAnalyser();return t.createMediaStreamSource(new MediaStream([e])).connect(n),this.inputAudioContext=t,{volumeProvider:F(n,t.sampleRate),analyser:n}}async setupOutputAnalysis(e,t,n){this.audioCaptureContext&&(this.audioCaptureContext.close().catch(()=>{}),this.audioCaptureContext=null);const i=new AudioContext;this.audioCaptureContext=i;const s=i.createAnalyser();s.fftSize=2048,s.smoothingTimeConstant=.8;const r=new MediaStream([e.mediaStreamTrack]),a=i.createMediaStreamSource(r),c=F(s,i.sampleRate);await ie(i.audioWorklet);const u=new AudioWorkletNode(i,"rawAudioProcessor");return u.port.postMessage({type:"setFormat",format:t.format,sampleRate:t.sampleRate}),u.port.onmessage=d=>{const[h,p]=d.data;n(h.buffer,p)},a.connect(s),s.connect(u),{volumeProvider:c,analyser:s}}setVolume(e){for(const t of this.audioElements)t.volume=e}async setOutputDevice(e){if(!("setSinkId"in HTMLAudioElement.prototype))throw new Error("setSinkId is not supported in this browser");await Promise.all(this.audioElements.map(async t=>{try{await t.setSinkId(e)}catch(n){throw console.error("Failed to set sink ID for audio element:",n),n}}))}cleanup(){this.inputAudioContext&&(this.inputAudioContext.close().catch(e=>{console.warn("Error closing input audio context:",e)}),this.inputAudioContext=null),this.audioCaptureContext&&(this.audioCaptureContext.close().catch(e=>{console.warn("Error closing audio capture context:",e)}),this.audioCaptureContext=null);for(const e of this.audioElements)e.remove();this.audioElements=[]}}let H=null;function nt(o){H=o}function ot(){if(!H)throw new Error("No Scribe microphone implementation registered. Import '@elevenlabs/client/platform/web' or provide a custom implementation via setScribeMicrophoneSetup().");return H}const it=B("scribeAudioProcessor",`/*
 * Scribe Audio Processor for converting microphone audio to PCM16 format
 * Supports resampling for browsers like Firefox that don't support
 * AudioContext sample rate constraints.
 * USED BY @elevenlabs/client
 */

class ScribeAudioProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.buffer = [];
    this.bufferSize = 4096; // Buffer size for optimal chunk transmission

    // Resampling state
    this.inputSampleRate = null;
    this.outputSampleRate = null;
    this.resampleRatio = 1;
    this.lastSample = 0;
    this.resampleAccumulator = 0;

    this.port.onmessage = ({ data }) => {
      if (data.type === "configure") {
        this.inputSampleRate = data.inputSampleRate;
        this.outputSampleRate = data.outputSampleRate;
        if (this.inputSampleRate && this.outputSampleRate) {
          this.resampleRatio = this.inputSampleRate / this.outputSampleRate;
        }
      }
    };
  }

  // Linear interpolation resampling
  resample(inputData) {
    if (this.resampleRatio === 1 || !this.inputSampleRate) {
      return inputData;
    }

    const outputSamples = [];

    for (let i = 0; i < inputData.length; i++) {
      const currentSample = inputData[i];

      // Generate output samples using linear interpolation
      while (this.resampleAccumulator < 1) {
        const interpolated =
          this.lastSample +
          (currentSample - this.lastSample) * this.resampleAccumulator;
        outputSamples.push(interpolated);
        this.resampleAccumulator += this.resampleRatio;
      }

      this.resampleAccumulator -= 1;
      this.lastSample = currentSample;
    }

    return new Float32Array(outputSamples);
  }

  process(inputs) {
    const input = inputs[0];
    if (input.length > 0) {
      let channelData = input[0]; // Get first channel (mono)

      // Resample if needed (for Firefox and other browsers that don't
      // support AudioContext sample rate constraints)
      if (this.resampleRatio !== 1) {
        channelData = this.resample(channelData);
      }

      // Add incoming audio to buffer
      for (let i = 0; i < channelData.length; i++) {
        this.buffer.push(channelData[i]);
      }

      // When buffer reaches threshold, convert and send
      if (this.buffer.length >= this.bufferSize) {
        const float32Array = new Float32Array(this.buffer);
        const int16Array = new Int16Array(float32Array.length);

        // Convert Float32 [-1, 1] to Int16 [-32768, 32767]
        for (let i = 0; i < float32Array.length; i++) {
          // Clamp the value to prevent overflow
          const sample = Math.max(-1, Math.min(1, float32Array[i]));
          // Scale to PCM16 range
          int16Array[i] = sample < 0 ? sample * 32768 : sample * 32767;
        }

        // Send to main thread as transferable ArrayBuffer
        this.port.postMessage(
          {
            audioData: int16Array.buffer
          },
          [int16Array.buffer]
        );

        // Clear buffer
        this.buffer = [];
      }
    }

    return true; // Continue processing
  }
}

registerProcessor("scribeAudioProcessor", ScribeAudioProcessor);

`),j=16e3,st=async(o,e)=>{const t=await navigator.mediaDevices.getUserMedia({audio:{deviceId:o.deviceId,echoCancellation:o.echoCancellation??!0,noiseSuppression:o.noiseSuppression??!0,autoGainControl:o.autoGainControl??!0,channelCount:o.channelCount??1,sampleRate:{ideal:j}}}),[n]=t.getAudioTracks(),i=n?.getSettings().sampleRate,s=new AudioContext(i?{sampleRate:i}:{});await it(s.audioWorklet);const r=s.createMediaStreamSource(t),a=new AudioWorkletNode(s,"scribeAudioProcessor");return s.sampleRate!==j&&a.port.postMessage({type:"configure",inputSampleRate:s.sampleRate,outputSampleRate:j}),a.port.onmessage=c=>{e(V(c.data.audioData))},r.connect(a),s.state==="suspended"&&await s.resume(),{mediaStreamTrack:n,cleanup:()=>{for(const c of t.getTracks())c.stop();r.disconnect(),a.disconnect(),s.close()}}},at="https://api.elevenlabs.io";async function rt({conversationId:o,origin:e,file:t,filename:n}){const i=(e??at).replace(/^wss:\/\//,"https://").replace(/^ws:\/\//,"http://"),s=n??("name"in t&&typeof t.name=="string"?t.name:`upload.${(t.type||"image/png").split("/").pop()?.split("+")[0]}`),r=new FormData;r.append("file",t,s);const a=await fetch(`${i}/v1/convai/conversations/${o}/files`,{method:"POST",body:r});if(!a.ok){const d=await K(a);throw new Error(`Upload failed: ${a.status} ${d}`)}const c=await a.json();we(c,"Upload response is not a JSON object");const{file_id:u}=c;if(typeof u!="string"||!u)throw new Error("Upload response is missing a valid file_id");return{fileId:u}}const he={reason:"agent",context:{type:"end_call",reason:"Agent ended the call"}};function pe(o){const{textOnly:e}=o.overrides?.conversation??{},{textOnly:t}=o;return typeof t=="boolean"?(typeof e=="boolean"&&t!==e&&console.warn(`Conflicting textOnly options provided: ${t} via options.textOnly (will be used) and ${e} via options.overrides.conversation.textOnly (will be ignored)`),t):typeof e=="boolean"?e:void 0}class O{options;connection;lastInterruptTimestamp=0;mode="listening";status="connecting";volume=1;currentEventId=1;canSendFeedback=!1;static getFullOptions(e){const t=pe(e);return{clientTools:{},onConnect:()=>{},onDebug:()=>{},onDisconnect:()=>{},onError:()=>{},onMessage:()=>{},onAudio:()=>{},onModeChange:()=>{},onStatusChange:()=>{},onCanSendFeedbackChange:()=>{},onInterruption:()=>{},onAgentResponseCorrection:()=>{},onAgentTyping:()=>{},onExternalAgentConnected:()=>{},onPing:()=>{},...e,textOnly:t,overrides:{...e.overrides,conversation:{...e.overrides?.conversation,textOnly:t}}}}constructor(e,t){this.options=e,this.connection=t,this.connection.onMessage(this.onMessage),this.connection.onDisconnect(this.endSessionWithDetails),this.connection.onModeChange(n=>this.updateMode(n))}markConnected(){this.updateStatus("connected")}endSession(){return this.endSessionWithDetails({reason:"user"})}endSessionWithDetails=async e=>{this.status!=="connected"&&this.status!=="connecting"||(this.updateStatus("disconnecting"),await this.handleEndSession(),this.updateStatus("disconnected"),this.options.onDisconnect&&this.options.onDisconnect(e))};async handleEndSession(){this.connection.close()}updateMode(e){e!==this.mode&&(this.mode=e,this.options.onModeChange&&this.options.onModeChange({mode:e}))}updateStatus(e){e!==this.status&&(this.status=e,this.options.onStatusChange&&this.options.onStatusChange({status:e}),this.updateCanSendFeedback())}updateCanSendFeedback(){const e=this.status==="connected";this.canSendFeedback!==e&&(this.canSendFeedback=e,this.options.onCanSendFeedbackChange&&this.options.onCanSendFeedbackChange({canSendFeedback:e}))}handleInterruption(e){e.interruption_event&&(this.lastInterruptTimestamp=e.interruption_event.event_id,this.options.onInterruption&&this.options.onInterruption({event_id:e.interruption_event.event_id}))}handleAgentResponse(e){this.currentEventId=e.agent_response_event.event_id,this.options.onMessage&&this.options.onMessage({source:"ai",role:"agent",message:e.agent_response_event.agent_response,event_id:e.agent_response_event.event_id})}handleAgentResponseCorrection(e){this.options.onAgentResponseCorrection&&this.options.onAgentResponseCorrection(e.agent_response_correction_event)}handleUserTranscript(e){this.options.onMessage&&this.options.onMessage({source:"user",role:"user",message:e.user_transcription_event.user_transcript,event_id:e.user_transcription_event.event_id})}handleTentativeAgentResponse(e){this.options.onDebug&&this.options.onDebug({type:"tentative_agent_response",response:e.tentative_agent_response_internal_event.tentative_agent_response})}handleVadScore(e){this.options.onVadScore&&this.options.onVadScore({vadScore:e.vad_score_event.vad_score})}handlePing(e){this.options.onPing&&this.options.onPing(e.ping_event)}async handleClientToolCall(e){if(Object.prototype.hasOwnProperty.call(this.options.clientTools,e.client_tool_call.tool_name))try{const t=await this.options.clientTools[e.client_tool_call.tool_name](e.client_tool_call.parameters)??"Client tool execution successful.",n=typeof t=="object"?JSON.stringify(t):String(t);this.connection.sendMessage({type:"client_tool_result",tool_call_id:e.client_tool_call.tool_call_id,result:n,is_error:!1})}catch(t){this.onError(`Client tool execution failed with following error: ${t?.message}`,{clientToolName:e.client_tool_call.tool_name}),this.connection.sendMessage({type:"client_tool_result",tool_call_id:e.client_tool_call.tool_call_id,result:`Client tool execution failed: ${t?.message}`,is_error:!0})}else{if(this.options.onUnhandledClientToolCall){this.options.onUnhandledClientToolCall(e.client_tool_call);return}this.onError(`Client tool with name ${e.client_tool_call.tool_name} is not defined on client`,{clientToolName:e.client_tool_call.tool_name}),this.connection.sendMessage({type:"client_tool_result",tool_call_id:e.client_tool_call.tool_call_id,result:`Client tool with name ${e.client_tool_call.tool_name} is not defined on client`,is_error:!0})}}handleAudio(e){}handleMCPToolCall(e){this.options.onMCPToolCall&&this.options.onMCPToolCall(e.mcp_tool_call)}handleMCPConnectionStatus(e){this.options.onMCPConnectionStatus&&this.options.onMCPConnectionStatus(e.mcp_connection_status)}handleAgentToolRequest(e){this.options.onAgentToolRequest&&this.options.onAgentToolRequest(e.agent_tool_request)}handleAgentToolResponse(e){e.agent_tool_response.tool_name==="end_call"&&this.endSessionWithDetails(he).catch(t=>{this.onError("Failed to end session after agent end_call",t)}),this.options.onAgentToolResponse?.(e.agent_tool_response)}handleAgentToolResponseFullPayload(e){e.agent_tool_response_full_payload.tool_name==="end_call"&&this.endSessionWithDetails(he).catch(t=>{this.onError("Failed to end session after agent end_call",t)}),this.options.onAgentToolResponse?.(e.agent_tool_response_full_payload)}handleConversationMetadata(e){this.options.onConversationMetadata&&this.options.onConversationMetadata(e.conversation_initiation_metadata_event)}handleAsrInitiationMetadata(e){this.options.onAsrInitiationMetadata&&this.options.onAsrInitiationMetadata(e.asr_initiation_metadata_event)}handleAgentChatResponsePart(e){this.options.onAgentChatResponsePart&&this.options.onAgentChatResponsePart(e.text_response_part)}handleGuardrailTriggered(e){this.options.onGuardrailTriggered&&this.options.onGuardrailTriggered()}handleAgentTyping(e){this.options.onAgentTyping&&this.options.onAgentTyping(e.agent_typing_event)}handleExternalAgentConnected(e){this.options.onExternalAgentConnected&&this.options.onExternalAgentConnected()}handleErrorEvent(e){const t=e.error_event.error_type,n=e.error_event.message||e.error_event.reason||"Unknown error";if(t==="max_duration_exceeded"){this.endSessionWithDetails({reason:"error",message:n,context:{type:"max_duration_exceeded"}}).catch(i=>{this.onError("Failed to end session after max_duration_exceeded",i)});return}this.onError(`Server error: ${n}`,{errorType:t,code:e.error_event.code,debugMessage:e.error_event.debug_message,details:e.error_event.details})}onMessage=async e=>{switch(e.type){case"interruption":{this.handleInterruption(e);return}case"agent_response":{this.handleAgentResponse(e);return}case"agent_response_correction":{this.handleAgentResponseCorrection(e);return}case"user_transcript":{this.handleUserTranscript(e);return}case"internal_tentative_agent_response":{this.handleTentativeAgentResponse(e);return}case"client_tool_call":{try{await this.handleClientToolCall(e)}catch(t){this.onError(`Unexpected error in client tool call handling: ${t instanceof Error?t.message:String(t)}`,{clientToolName:e.client_tool_call.tool_name,toolCallId:e.client_tool_call.tool_call_id})}return}case"audio":{this.handleAudio(e);return}case"vad_score":{this.handleVadScore(e);return}case"ping":{this.connection.sendMessage({type:"pong",event_id:e.ping_event.event_id}),this.handlePing(e);return}case"mcp_tool_call":{this.handleMCPToolCall(e);return}case"mcp_connection_status":{this.handleMCPConnectionStatus(e);return}case"agent_tool_request":{this.handleAgentToolRequest(e);return}case"agent_tool_response":{this.handleAgentToolResponse(e);return}case"agent_tool_response_full_payload":{this.handleAgentToolResponseFullPayload(e);return}case"conversation_initiation_metadata":{this.handleConversationMetadata(e);return}case"asr_initiation_metadata":{this.handleAsrInitiationMetadata(e);return}case"agent_chat_response_part":{this.handleAgentChatResponsePart(e);return}case"guardrail_triggered":{this.handleGuardrailTriggered(e);return}case"error":{this.handleErrorEvent(e);return}case"agent_typing":{this.handleAgentTyping(e);return}case"external_agent_connected":{this.handleExternalAgentConnected(e);return}default:{this.options.onDebug&&this.options.onDebug(e);return}}};onError(e,t){console.error(e,t),this.options.onError&&this.options.onError(e,t)}getId(){return this.connection.conversationId}isOpen(){return this.status==="connected"}sendFeedback(e,t){if(!this.canSendFeedback){console.warn("Cannot send feedback: the conversation is not connected.");return}this.connection.sendMessage({type:"feedback",score:e!==null?e?"like":"dislike":null,event_id:t??this.currentEventId})}sendContextualUpdate(e,t){this.connection.sendMessage({type:"contextual_update",text:e,...t?.contextId?{context_id:t.contextId}:{}})}sendUserMessage(e){this.connection.sendMessage({type:"user_message",text:e})}sendUserActivity(){this.connection.sendMessage({type:"user_activity"})}sendMCPToolApprovalResult(e,t){this.connection.sendMessage({type:"mcp_tool_approval_result",tool_call_id:e,is_approved:t})}sendMultimodalMessage(e){this.connection.sendMessage({type:"multimodal_message",text:e.text?{type:"user_message",text:e.text}:void 0,file:e.fileId?{type:"file_input",file_id:e.fileId}:void 0})}async uploadFile(e){return rt({conversationId:this.connection.conversationId,origin:this.options.origin,file:e})}}function ct(){const o=["fetch","WebSocket","TextEncoder","TextDecoder","URL","btoa","atob"];for(const e of o)if(typeof globalThis[e]>"u")throw new Error(`${e} is not available in this environment.`)}const me=new Uint8Array(0);class L extends O{type="text";setVolume(){throw new Error("setVolume is not supported in text conversations")}setMicMuted(){throw new Error("setMicMuted is not supported in text conversations")}getInputByteFrequencyData(){return me}getOutputByteFrequencyData(){return me}getInputVolume(){return 0}getOutputVolume(){return 0}static async startSession(e){const t=O.getFullOptions(e);t.onStatusChange&&t.onStatusChange({status:"connecting"}),t.onCanSendFeedbackChange&&t.onCanSendFeedbackChange({canSendFeedback:!1}),t.onModeChange&&t.onModeChange({mode:"listening"}),t.onCanSendFeedbackChange&&t.onCanSendFeedbackChange({canSendFeedback:!1});let n=null,i=null;try{return await ce(re(t.connectionDelay)),n=await $(t),i=new L(t,n),t.onConversationCreated?.(i),i.markConnected(),t.onConnect?.({conversationId:n.conversationId}),i}catch(s){throw i?await i.endSession().catch(()=>{}):(t.onStatusChange?.({status:"disconnected"}),n?.close()),s}}}class k extends O{input;output;playbackEventTarget;cleanUp;type="voice";static async startSession(e){const t=O.getFullOptions(e);t.onStatusChange&&t.onStatusChange({status:"connecting"}),t.onCanSendFeedbackChange&&t.onCanSendFeedbackChange({canSendFeedback:!1});let n=null,i=null;try{if(!W)throw new Error('No voice session setup strategy registered. Import the platform-specific entry point (e.g. @elevenlabs/client via the "browser" export).');return i=await W(t),n=new k(t,i.connection,i.input,i.output,i.playbackEventTarget,i.detach),t.onConversationCreated?.(n),n.markConnected(),t.onConnect?.({conversationId:i.connection.conversationId}),n}catch(s){throw n?await n.endSession().catch(()=>{}):(i&&await i.detach().catch(()=>{}),t.onStatusChange?.({status:"disconnected"})),s}}inputFrequencyData;outputFrequencyData;handlePlaybackEvent=e=>{e.data.type==="process"&&this.updateMode(e.data.finished?"listening":"speaking")};constructor(e,t,n,i,s,r){super(e,t),this.input=n,this.output=i,this.playbackEventTarget=s,this.cleanUp=r,s?.addListener(this.handlePlaybackEvent)}async handleEndSession(){this.playbackEventTarget?.removeListener(this.handlePlaybackEvent),this.playbackEventTarget=null,await this.cleanUp(),await super.handleEndSession(),await this.input.close(),await this.output.close()}handleInterruption(e){super.handleInterruption(e),this.updateMode("listening"),this.output.interrupt()}handleAudio(e){super.handleAudio(e),e.audio_event.alignment&&this.options.onAudioAlignment&&this.options.onAudioAlignment(e.audio_event.alignment),this.lastInterruptTimestamp<=e.audio_event.event_id&&(e.audio_event.audio_base_64&&this.options.onAudio?.(e.audio_event.audio_base_64),this.currentEventId=e.audio_event.event_id,this.updateCanSendFeedback(),this.updateMode("speaking"))}static FREQUENCY_BIN_COUNT=1024;setMicMuted(e){this.input.setMuted(e).catch(t=>{this.options.onError?.("Failed to set input muted state",t)})}getInputByteFrequencyData(){return this.inputFrequencyData??=new Uint8Array(k.FREQUENCY_BIN_COUNT),this.input.getByteFrequencyData(this.inputFrequencyData),this.inputFrequencyData}getOutputByteFrequencyData(){return this.outputFrequencyData??=new Uint8Array(k.FREQUENCY_BIN_COUNT),this.output.getByteFrequencyData(this.outputFrequencyData),this.outputFrequencyData}getInputVolume(){return this.input.getVolume()}getOutputVolume(){return this.output.getVolume()}async changeInputDevice({sampleRate:e,format:t,preferHeadphonesForIosDevices:n,inputDeviceId:i}){try{await this.input.setDevice({inputDeviceId:i,sampleRate:e,format:t,preferHeadphonesForIosDevices:n})}catch(s){throw console.error("Error changing input device",s),s}}async changeOutputDevice({sampleRate:e,format:t,outputDeviceId:n}){try{await this.output.setDevice({outputDeviceId:n,sampleRate:e,format:t})}catch(i){throw console.error("Error changing output device",i),i}}setVolume=({volume:e})=>{const t=Number.isFinite(e)?Math.min(1,Math.max(0,e)):1;this.volume=t,this.output.setVolume(t)}}const ut="https://api.elevenlabs.io";function lt(o,e,t=ut){const n={};return typeof e=="boolean"?n.feedback=e?"like":"dislike":(n.rating=e.rating,n.comment=e.comment),fetch(`${t}/v1/convai/conversations/${o}/feedback`,{method:"POST",body:JSON.stringify(n),headers:{"Content-Type":"application/json"}})}class dt{listeners=new Map;on(e,t){this.listeners.has(e)||this.listeners.set(e,new Set);const n=this.listeners.get(e);n&&n.add(t)}off(e,t){const n=this.listeners.get(e);n&&n.delete(t)}emit(e,...t){const n=this.listeners.get(e);n&&n.forEach(i=>{i(...t)})}}var l;(function(o){o.SESSION_STARTED="session_started",o.PARTIAL_TRANSCRIPT="partial_transcript",o.COMMITTED_TRANSCRIPT="committed_transcript",o.COMMITTED_TRANSCRIPT_WITH_TIMESTAMPS="committed_transcript_with_timestamps",o.AUTH_ERROR="auth_error",o.ERROR="error",o.OPEN="open",o.CLOSE="close",o.QUOTA_EXCEEDED="quota_exceeded",o.COMMIT_THROTTLED="commit_throttled",o.TRANSCRIBER_ERROR="transcriber_error",o.UNACCEPTED_TERMS="unaccepted_terms",o.RATE_LIMITED="rate_limited",o.INPUT_ERROR="input_error",o.QUEUE_OVERFLOW="queue_overflow",o.RESOURCE_EXHAUSTED="resource_exhausted",o.SESSION_TIME_LIMIT_EXCEEDED="session_time_limit_exceeded",o.CHUNK_SIZE_EXCEEDED="chunk_size_exceeded",o.INSUFFICIENT_AUDIO_ACTIVITY="insufficient_audio_activity"})(l||(l={}));class fe{websocket=null;eventEmitter=new dt;currentSampleRate=16e3;_muted=!1;_audioCleanup;_mediaStreamTrack;constructor(e){this.currentSampleRate=e}get isMuted(){return this._muted}getMediaStreamTrackForMute(e){if(!this._mediaStreamTrack)throw new Error(`Cannot ${e} audio without an active microphone MediaStreamTrack. mute() and unmute() are only supported for microphone connections.`);return this._mediaStreamTrack}mute(){const e=this.getMediaStreamTrackForMute("mute");this._muted=!0,e.enabled=!1}unmute(){const e=this.getMediaStreamTrackForMute("unmute");this._muted=!1,e.enabled=!0}setWebSocket(e){this.websocket=e,this.websocket.readyState===WebSocket.OPEN?this.eventEmitter.emit(l.OPEN):this.websocket.addEventListener("open",()=>{this.eventEmitter.emit(l.OPEN)}),this.websocket.addEventListener("message",t=>{try{const n=JSON.parse(t.data);switch(n.message_type){case"session_started":this.eventEmitter.emit(l.SESSION_STARTED,n);break;case"partial_transcript":this.eventEmitter.emit(l.PARTIAL_TRANSCRIPT,n);break;case"committed_transcript":this.eventEmitter.emit(l.COMMITTED_TRANSCRIPT,n);break;case"committed_transcript_with_timestamps":this.eventEmitter.emit(l.COMMITTED_TRANSCRIPT_WITH_TIMESTAMPS,n);break;case"auth_error":this.eventEmitter.emit(l.AUTH_ERROR,n),this.eventEmitter.emit(l.ERROR,n);break;case"quota_exceeded":this.eventEmitter.emit(l.QUOTA_EXCEEDED,n),this.eventEmitter.emit(l.ERROR,n);break;case"commit_throttled":this.eventEmitter.emit(l.COMMIT_THROTTLED,n),this.eventEmitter.emit(l.ERROR,n);break;case"transcriber_error":this.eventEmitter.emit(l.TRANSCRIBER_ERROR,n),this.eventEmitter.emit(l.ERROR,n);break;case"unaccepted_terms":this.eventEmitter.emit(l.UNACCEPTED_TERMS,n),this.eventEmitter.emit(l.ERROR,n);break;case"rate_limited":this.eventEmitter.emit(l.RATE_LIMITED,n),this.eventEmitter.emit(l.ERROR,n);break;case"input_error":this.eventEmitter.emit(l.INPUT_ERROR,n),this.eventEmitter.emit(l.ERROR,n);break;case"queue_overflow":this.eventEmitter.emit(l.QUEUE_OVERFLOW,n),this.eventEmitter.emit(l.ERROR,n);break;case"resource_exhausted":this.eventEmitter.emit(l.RESOURCE_EXHAUSTED,n),this.eventEmitter.emit(l.ERROR,n);break;case"session_time_limit_exceeded":this.eventEmitter.emit(l.SESSION_TIME_LIMIT_EXCEEDED,n),this.eventEmitter.emit(l.ERROR,n);break;case"chunk_size_exceeded":this.eventEmitter.emit(l.CHUNK_SIZE_EXCEEDED,n),this.eventEmitter.emit(l.ERROR,n);break;case"insufficient_audio_activity":this.eventEmitter.emit(l.INSUFFICIENT_AUDIO_ACTIVITY,n),this.eventEmitter.emit(l.ERROR,n);break;case"error":this.eventEmitter.emit(l.ERROR,n);break;default:console.warn("Unknown message type:",n)}}catch(n){console.error("Failed to parse WebSocket message:",n,t.data),this.eventEmitter.emit(l.ERROR,new Error(`Failed to parse message: ${n}`))}}),this.websocket.addEventListener("error",t=>{console.error("WebSocket error:",t),this.eventEmitter.emit(l.ERROR,t)}),this.websocket.addEventListener("close",t=>{if(console.log(`WebSocket closed: code=${t.code}, reason="${t.reason}", wasClean=${t.wasClean}`),!t.wasClean||t.code!==1e3&&t.code!==1005){const n=`WebSocket closed unexpectedly: ${t.code} - ${t.reason||"No reason provided"}`;console.error(n),this.eventEmitter.emit(l.ERROR,new Error(n))}this.eventEmitter.emit(l.CLOSE,t)})}on(e,t){this.eventEmitter.on(e,t)}off(e,t){this.eventEmitter.off(e,t)}send(e){if(!this.websocket||this.websocket.readyState!==WebSocket.OPEN)throw new Error("WebSocket is not connected");const t={message_type:"input_audio_chunk",audio_base_64:e.audioBase64,commit:e.commit??!1,sample_rate:e.sampleRate??this.currentSampleRate,previous_text:e.previousText};this.websocket.send(JSON.stringify(t))}commit(){if(!this.websocket||this.websocket.readyState!==WebSocket.OPEN)throw new Error("WebSocket is not connected");const e={message_type:"input_audio_chunk",audio_base_64:"",commit:!0,sample_rate:this.currentSampleRate};this.websocket.send(JSON.stringify(e))}close(){this._audioCleanup&&this._audioCleanup(),this.websocket&&this.websocket.close(1e3,"User ended session")}}var G;(function(o){o.PCM_8000="pcm_8000",o.PCM_16000="pcm_16000",o.PCM_22050="pcm_22050",o.PCM_24000="pcm_24000",o.PCM_44100="pcm_44100",o.PCM_48000="pcm_48000",o.ULAW_8000="ulaw_8000"})(G||(G={}));var z;(function(o){o.MANUAL="manual",o.VAD="vad"})(z||(z={}));class C{static DEFAULT_BASE_URI="wss://api.elevenlabs.io";static getWebSocketUri(e=C.DEFAULT_BASE_URI){return`${e}/v1/speech-to-text/realtime`}static buildWebSocketUri(e){const t=C.getWebSocketUri(e.baseUri),n=new URLSearchParams;if(n.append("model_id",e.modelId),n.append("token",e.token),e.commitStrategy!==void 0&&n.append("commit_strategy",e.commitStrategy),e.audioFormat!==void 0&&n.append("audio_format",e.audioFormat),e.vadSilenceThresholdSecs!==void 0){if(e.vadSilenceThresholdSecs<=.3||e.vadSilenceThresholdSecs>3)throw new Error("vadSilenceThresholdSecs must be between 0.3 and 3.0");n.append("vad_silence_threshold_secs",e.vadSilenceThresholdSecs.toString())}if(e.vadThreshold!==void 0){if(e.vadThreshold<.1||e.vadThreshold>.9)throw new Error("vadThreshold must be between 0.1 and 0.9");n.append("vad_threshold",e.vadThreshold.toString())}if(e.minSpeechDurationMs!==void 0){if(e.minSpeechDurationMs<=50||e.minSpeechDurationMs>2e3)throw new Error("minSpeechDurationMs must be between 50 and 2000");n.append("min_speech_duration_ms",e.minSpeechDurationMs.toString())}if(e.minSilenceDurationMs!==void 0){if(e.minSilenceDurationMs<=50||e.minSilenceDurationMs>2e3)throw new Error("minSilenceDurationMs must be between 50 and 2000");n.append("min_silence_duration_ms",e.minSilenceDurationMs.toString())}if(e.languageCode!==void 0&&n.append("language_code",e.languageCode),e.includeTimestamps!==void 0&&n.append("include_timestamps",e.includeTimestamps?"true":"false"),e.includeLanguageDetection!==void 0&&n.append("include_language_detection",e.includeLanguageDetection?"true":"false"),e.keyterms!==void 0)for(const s of e.keyterms)n.append("keyterms",s);e.noVerbatim!==void 0&&n.append("no_verbatim",e.noVerbatim?"true":"false");const i=n.toString();return i?`${t}?${i}`:t}static connect(e){if(!e.modelId)throw new Error("modelId is required");const t="microphone"in e&&e.microphone?16e3:e.sampleRate,n=new fe(t),i=C.buildWebSocketUri(e),s=new WebSocket(i);return"microphone"in e&&e.microphone&&s.addEventListener("open",()=>{C.streamFromMicrophone(e,n)}),n.setWebSocket(s),n}static async streamFromMicrophone(e,t){try{const i=await ot()(e.microphone??{},s=>{t.send({audioBase64:s})});t._mediaStreamTrack=i.mediaStreamTrack,t._audioCleanup=i.cleanup}catch(n){throw console.error("Failed to start microphone streaming:",n),n}}}const ht={async startSession(o){return ct(),pe(o)?L.startSession(o):k.startSession(o)}};Qe(),Ee(()=>new tt),nt(st);export{G as AudioFormat,z as CommitStrategy,ht as Conversation,se as DEFAULT_INPUT_CHUNK_DURATION_MS,fe as RealtimeConnection,l as RealtimeEvents,C as Scribe,U as SessionConnectionError,L as TextConversation,k as VoiceConversation,A as WebRTCConnection,I as WebSocketConnection,$ as createConnection,lt as postOverallFeedback};
//# sourceMappingURL=/sm/75e25f98f0ac894662c7d99771575ade5fd391258ac5d03d4473a7f264efc2bc.map