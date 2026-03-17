# typed: true
# RBI stubs for FFI driver modules (SDL2, SFML, Ao)
# These methods are created dynamically via attach_function at runtime.

module Optcarrot
  module SDL2
    # Functions attached via attach_function
    sig { params(flags: Integer).returns(Integer) }
    def self.InitSubSystem(flags); end

    sig { params(flags: Integer).void }
    def self.QuitSubSystem(flags); end

    sig { params(ms: Integer).void }
    def self.Delay(ms); end

    sig { returns(String) }
    def self.GetError; end

    sig { returns(Integer) }
    def self.GetTicks; end

    sig { params(title: String, x: Integer, y: Integer, w: Integer, h: Integer, flags: Integer).returns(T.untyped) }
    def self.CreateWindow(title, x, y, w, h, flags); end

    sig { params(window: T.untyped).void }
    def self.DestroyWindow(window); end

    sig { params(window: T.untyped, index: Integer, flags: Integer).returns(T.untyped) }
    def self.CreateRenderer(window, index, flags); end

    sig { params(renderer: T.untyped).void }
    def self.DestroyRenderer(renderer); end

    sig { params(pixels: T.untyped, width: Integer, height: Integer, depth: Integer, pitch: Integer, rmask: Integer, gmask: Integer, bmask: Integer, amask: Integer).returns(T.untyped) }
    def self.CreateRGBSurfaceFrom(pixels, width, height, depth, pitch, rmask, gmask, bmask, amask); end

    sig { params(surface: T.untyped).void }
    def self.FreeSurface(surface); end

    sig { params(window: T.untyped).returns(Integer) }
    def self.GetWindowFlags(window); end

    sig { params(window: T.untyped, flags: Integer).returns(Integer) }
    def self.SetWindowFullscreen(window, flags); end

    sig { params(window: T.untyped, w: Integer, h: Integer).void }
    def self.SetWindowSize(window, w, h); end

    sig { params(window: T.untyped, title: String).void }
    def self.SetWindowTitle(window, title); end

    sig { params(window: T.untyped, icon: T.untyped).void }
    def self.SetWindowIcon(window, icon); end

    sig { params(name: String, value: String).returns(Integer) }
    def self.SetHint(name, value); end

    sig { params(renderer: T.untyped, w: Integer, h: Integer).returns(Integer) }
    def self.RenderSetLogicalSize(renderer, w, h); end

    sig { params(renderer: T.untyped, format: Integer, access: Integer, w: Integer, h: Integer).returns(T.untyped) }
    def self.CreateTexture(renderer, format, access, w, h); end

    sig { params(texture: T.untyped).void }
    def self.DestroyTexture(texture); end

    sig { params(event: T.untyped).returns(Integer) }
    def self.PollEvent(event); end

    sig { params(texture: T.untyped, rect: T.untyped, pixels: T.untyped, pitch: Integer).returns(Integer) }
    def self.UpdateTexture(texture, rect, pixels, pitch); end

    sig { params(renderer: T.untyped).returns(Integer) }
    def self.RenderClear(renderer); end

    sig { params(renderer: T.untyped, texture: T.untyped, srcrect: T.untyped, dstrect: T.untyped).returns(Integer) }
    def self.RenderCopy(renderer, texture, srcrect, dstrect); end

    sig { params(renderer: T.untyped).returns(Integer) }
    def self.RenderPresent(renderer); end

    sig { params(device: T.untyped, iscapture: Integer, desired: T.untyped, obtained: T.untyped, allowed_changes: Integer).returns(Integer) }
    def self.OpenAudioDevice(device, iscapture, desired, obtained, allowed_changes); end

    sig { params(dev: Integer, pause_on: Integer).void }
    def self.PauseAudioDevice(dev, pause_on); end

    sig { params(dev: Integer).void }
    def self.CloseAudioDevice(dev); end

    sig { returns(Integer) }
    def self.NumJoysticks; end

    sig { params(device_index: Integer).returns(T.untyped) }
    def self.JoystickOpen(device_index); end

    sig { params(joystick: T.untyped).void }
    def self.JoystickClose(joystick); end

    sig { params(device_index: Integer).returns(String) }
    def self.JoystickNameForIndex(device_index); end

    sig { params(joystick: T.untyped).returns(Integer) }
    def self.JoystickNumAxes(joystick); end

    sig { params(joystick: T.untyped).returns(Integer) }
    def self.JoystickNumButtons(joystick); end

    sig { params(joystick: T.untyped).returns(Integer) }
    def self.JoystickInstanceID(joystick); end

    sig { params(dev: Integer, data: T.untyped, len: Integer).returns(Integer) }
    def self.QueueAudio(dev, data, len); end

    sig { params(dev: Integer).returns(Integer) }
    def self.GetQueuedAudioSize(dev); end

    sig { params(dev: Integer).void }
    def self.ClearQueuedAudio(dev); end

    sig { params(blk: T.untyped).returns(T.untyped) }
    def self.AudioCallback(blk); end

    sig { params(version: T.untyped).void }
    def self.GetVersion(version); end
  end

  module SFML
    sig { returns(T.untyped) }
    def self.sfClock_create; end

    sig { params(clock: T.untyped).void }
    def self.sfClock_destroy(clock); end

    sig { params(clock: T.untyped).returns(Integer) }
    def self.sfClock_getElapsedTime(clock); end

    sig { params(clock: T.untyped).returns(Integer) }
    def self.sfClock_restart(clock); end

    sig { params(mode: T.untyped, title: String, style: Integer, settings: T.untyped).returns(T.untyped) }
    def self.sfRenderWindow_create(mode, title, style, settings); end

    sig { params(window: T.untyped, color: T.untyped).void }
    def self.sfRenderWindow_clear(window, color); end

    sig { params(window: T.untyped, sprite: T.untyped, states: T.untyped).void }
    def self.sfRenderWindow_drawSprite(window, sprite, states); end

    sig { params(window: T.untyped).void }
    def self.sfRenderWindow_display(window); end

    sig { params(window: T.untyped).void }
    def self.sfRenderWindow_close(window); end

    sig { params(window: T.untyped).returns(Integer) }
    def self.sfRenderWindow_isOpen(window); end

    sig { params(window: T.untyped, event: T.untyped).returns(Integer) }
    def self.sfRenderWindow_pollEvent(window, event); end

    sig { params(window: T.untyped).void }
    def self.sfRenderWindow_destroy(window); end

    sig { params(window: T.untyped, title: T.untyped).void }
    def self.sfRenderWindow_setTitle(window, title); end

    sig { params(window: T.untyped, size: T.untyped).void }
    def self.sfRenderWindow_setSize(window, size); end

    sig { params(window: T.untyped, limit: Integer).void }
    def self.sfRenderWindow_setFramerateLimit(window, limit); end

    sig { params(window: T.untyped, enabled: Integer).void }
    def self.sfRenderWindow_setKeyRepeatEnabled(window, enabled); end

    sig { params(window: T.untyped, view: T.untyped).void }
    def self.sfRenderWindow_setView(window, view); end

    sig { params(window: T.untyped, width: Integer, height: Integer, pixels: T.untyped).void }
    def self.sfRenderWindow_setIcon(window, width, height, pixels); end

    sig { params(width: Integer, height: Integer).returns(T.untyped) }
    def self.sfTexture_create(width, height); end

    sig { params(texture: T.untyped, pixels: T.untyped, width: Integer, height: Integer, x: Integer, y: Integer).void }
    def self.sfTexture_updateFromPixels(texture, pixels, width, height, x, y); end

    sig { returns(T.untyped) }
    def self.sfSprite_create; end

    sig { params(sprite: T.untyped, texture: T.untyped, reset_rect: Integer).void }
    def self.sfSprite_setTexture(sprite, texture, reset_rect); end

    sig { returns(T.untyped) }
    def self.sfView_create; end

    sig { params(view: T.untyped).void }
    def self.sfView_destroy(view); end

    sig { params(view: T.untyped, center: T.untyped).void }
    def self.sfView_setCenter(view, center); end

    sig { params(view: T.untyped, size: T.untyped).void }
    def self.sfView_setSize(view, size); end

    sig { params(callback: T.untyped, seek: T.untyped, channel_count: Integer, sample_rate: Integer, userdata: T.untyped).returns(T.untyped) }
    def self.sfSoundStream_create(callback, seek, channel_count, sample_rate, userdata); end

    sig { params(stream: T.untyped).void }
    def self.sfSoundStream_destroy(stream); end

    sig { params(stream: T.untyped).void }
    def self.sfSoundStream_play(stream); end

    sig { params(stream: T.untyped).void }
    def self.sfSoundStream_stop(stream); end

    sig { params(blk: T.untyped).returns(T.untyped) }
    def self.SoundStreamGetDataCallback(blk); end

    sig { params(rect: T.untyped).returns(T.untyped) }
    def self.sfView_createFromRect(rect); end

    sig { params(view: T.untyped, rect: T.untyped).void }
    def self.sfView_reset(view, rect); end
  end

  module Ao
    sig { void }
    def self.initialize; end

    sig { returns(Integer) }
    def self.default_driver_id; end

    sig { params(driver_id: Integer, format: T.untyped, options: T.untyped).returns(T.untyped) }
    def self.open_live(driver_id, format, options); end

    sig { params(device: T.untyped, output_samples: T.untyped, num_bytes: Integer).returns(Integer) }
    def self.play(device, output_samples, num_bytes); end

    sig { params(device: T.untyped).returns(Integer) }
    def self.close(device); end

    sig { void }
    def self.shutdown; end
  end
end
