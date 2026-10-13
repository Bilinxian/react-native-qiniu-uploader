import {TurboModule, TurboModuleRegistry} from 'react-native';
import {uploadParams} from './type'
export interface Spec extends TurboModule {
  startTask(params: uploadParams): Promise<string>;
  resumeTask(): void
  pauseTask(): void
  addListener(eventName: string): void;

  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Qiniu');