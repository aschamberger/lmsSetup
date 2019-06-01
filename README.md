# lmsSetup

I wanted to be able to stream audio to/from a USB sound interface via [Logitech Media Server](https://www.mysqueezebox.com/download). The LMS is running on my NAS ([unRAID](https://lime-technology.com/)) in a [Docker](https://hub.Docker.com/r/snoopy86/logitechmediaserver/).
unRAID does not have any USB sound drivers enabled in the kernel. As this is also the case with DVB devices there is a [unRAID DVB Edition](https://lime-technology.com/forums/topic/46194-unraid-dvb-edition/) built by unRAID users. These builds also don't have USB sound support. Therefore I had to build the kernel by myself (based on the LibreELEC unRAID DVB build).

I tried this [USB Sound Card w/ Line In](https://www.amazon.de/DIGIFLEX-Externe-Soundkarte-6-Kanal-Audio/dp/B003TO3KHY/ref=sr_1_1?s=computers&ie=UTF8&qid=1515340605&sr=1-1)
and another [USB Sound Card w/ Mic In](https://www.amazon.de/CSL-Externe-Soundkarte-Virtual-Surround/dp/B00C7LXUDY/ref=sr_1_1?s=computers&ie=UTF8&qid=1515247934&sr=1-1).

## Installation / Configuration

1. Compile Kernel with USB Sound support ([based on DVB build](https://github.com/CHBMB/Unraid-DVB/)):
    1. Download build script:
        ```
        rm -r /mnt/cache/appdata/__snd_kernel
        mkdir /mnt/cache/appdata/__snd_kernel
        wget https://raw.githubusercontent.com/CHBMB/Unraid-DVB/master/build_scripts/kernel-compile-module.sh -P /mnt/cache/appdata/__snd_kernel
        chmod +x /mnt/cache/appdata/__snd_kernel/*.sh
        ```
    1. Activate USB sound in *.config*:
        ```
        wget https://lsio.ams3.digitaloceanspaces.com/unraid-dvb/6-7-0/stock/.config -P /mnt/cache/appdata/__snd_kernel
        sed -i -r 's/# (CONFIG_SND_USB.+) is not set/\1=m/' /mnt/cache/appdata/__snd_kernel/.config
	sed -i -r 's/# (CONFIG_SND_BCD2000) is not set/\1=m/' /mnt/cache/appdata/__snd_kernel/.config
	sed -i '/^CONFIG_SND_USB_CAIAQ=m/a CONFIG_SND_USB_CAIAQ_INPUT=y' /mnt/cache/appdata/__snd_kernel/.config
        ```
    1. Run build scripts:
        ```
        cd /mnt/cache/appdata/__snd_kernel/
        kernel-compile-module.sh
        ```
    1. Install:
        ```
        cd /mnt/cache/appdata/__snd_kernel/6-7-0/stock
        cp bzimage-new /boot/bzimage
        cp bzmodules-new /boot/bzmodules
        cp bzfirmware-new /boot/bzfirmware
        ```
    1. Reboot:
        ```
        powerdown -r
        ```
1. [Changing ALSA card IDs with udev](http://www.alsa-project.org/main/index.php/Changing_card_IDs_with_udev) (@see: [#1](https://lime-technology.com/forums/topic/47103-network-interfaces-keep-changing-names-how-do-i-fix-this/?tab=comments#comment-464770), [#2](https://unix.stackexchange.com/a/39485))
    1. Download *85-my-usb-audio.rules* to */boot/config/* and edit USB path to match setup:
        ```
        wget https://raw.githubusercontent.com/aschamberger/lmsSetup/master/85-my-usb-audio.rules -P /boot/config/
        vi /boot/config/85-my-usb-audio.rules
        ```
    1. Edit */boot/config/go* to install custom udev rules stored in */boot/config/* from thumbdrive on every reboot into memory:
        ```
        sudo sh -c "echo '' >> /boot/config/go"
        sudo sh -c "echo '# setup USB audio udev rules' >> /boot/config/go"
        sudo sh -c "echo 'yes | cp -rf /boot/config/85-my-usb-audio.rules /etc/udev/rules.d/' >> /boot/config/go"
        sudo sh -c "echo 'udevadm control --reload-rules' >> /boot/config/go"
        sudo sh -c "echo 'udevadm trigger -c remove -s sound' >> /boot/config/go"
        sudo sh -c "echo 'udevadm trigger -c add -s sound' >> /boot/config/go"
        ```
    1. Show available sound cards:
        ```
        cat /proc/asound/cards
        ```
1. Add Docker Repository in unRAID WebGUI:
   ```
   https://github.com/aschamberger/lmsSetup
   ```
1. Install Logitech Media Server Docker:
    1. Go to Docker Admin --> press "*Add Container*" --> in "*Template*" select "*lms-docker*"
    1. Install LMS Plugin AirPlay Bridge ([Support Thread](http://forums.slimdevices.com/showthread.php?105198-ANNOUNCE-AirPlay-Bridge-integrate-AirPlay-devices-with-LMS-(squeeze2raop)), [GitHub](https://github.com/philippe44/LMS-to-Raop)):
        * With the AirPlay Bridge it is possible to easily integrate a AVR receiver ([e.g my Pioneer VSX-831](http://www.pioneer-audiovisual.eu/de/def/products/vsx-831)).
        * It provides synchronisation, replaygain, gapless, fade in/out/cross and all other LMS goodies.
    1. Install LMS PluginPlayer Groups ([Support Thread](http://forums.slimdevices.com/showthread.php?108421-ANNOUNCE-Player-Groups-(alpha-version)), [GitHub](https://github.com/philippe44/LMS-Groups)):
    1. Maybe later: LMS Plugin ShairTunes2W ([Support Thread](http://forums.slimdevices.com/showthread.php?106289-announce-ShairTunes2W-Airtunes-on-LMS-(forked-version-with-Windows-support)), [GitHub](https://github.com/philippe44/ShairTunes2)):
1. Install Sqeezelite Docker (squeezelite: [github](https://github.com/ralph-irving/squeezelite), [builds](https://sourceforge.net/projects/lmsclients/)):
    1. Go to Docker Admin --> press "*Add Container*" --> in "*Template*" select "*lms-squeezelite*"
    1. Setup */config/alsa.sh*:
        ```
        amixer -D hw:CARD=SND_A sset Speaker 80% mute # CSL
        amixer -D hw:CARD=SND_A sset Mic 80% cap mute # CSL
        ```
1. Install Icecast 2 Docker:
    1. Go to Docker Admin --> press "*Add Container*" --> in "*Template*" select "*lms-icecast*"
    1. Edit *icecast.xml* and change *hostname* (@see [Icecast Basic Setup](http://www.icecast.org/docs/icecast-2.4.1/basic-setup.html), [Icecast Config File](http://www.icecast.org/docs/icecast-2.4.1/config-file.html))
        ```
        ...
        <hostname>localhost</hostname>
        ...
        ```
1. Install Liquidsoap Docker:
    1. Go to Docker Admin --> press "*Add Container*" --> in "*Template*" select "*lms-liquidsoap*"
    1. Setup */config/alsa.sh*:
        ```
        amixer -D hw:CARD=SND_B sset Speaker 80% mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset Mic 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset Line 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset PCM 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset 'PCM Capture Source' Line # DIGIFLEX
        ```
    1. Edit *liquidsoap.liq* and change *device* ([@see](http://liquidsoap.info/doc-dev/reference.html#input_alsa))
        ```
        ...
        input = input.alsa(bufferize=true,fallible=false,device="default:SND_A")
        ...
        ```
    1. Edit *liquidsoap.liq* and change *mount* ([@see](http://liquidsoap.info/doc-dev/reference.html#output_icecast))
        ```
        ...
        output.icecast(%ogg(%flac(samplerate=44100,channels=2,compression=5,bits_per_sample=16)), host="localhost", port=8000, password="hackme", mount="/input.ogg", name="Input", format="audio/ogg", description="Input Stream", input)
        ...
        ```
    1. Listen to stream at:
        ```
        ...
        http://<host or IP>:8000/input.ogg
        ...
        ```

## Development

1. Setting ALSA card id manually for testing:
    ```
    cat /proc/asound/cards
    echo -n SND_A > /sys/devices/pci0000:00/0000:00:16.0/usb1/1-1/1-1.1/1-1.1.1/1-1.1.1:1.0/sound/card0/id
    echo -n SND_B > /sys/devices/pci0000:00/0000:00:16.0/usb1/1-1/1-1.1/1-1.1.2/1-1.1.2:1.0/sound/card1/id
    cat /proc/asound/cards
    ```
1. [Docker test](https://github.com/phusion/baseimage-Docker#inspecting-baseimage-Docker)
    1. Start Docker container with *--device=/dev/snd/* ([@see](https://lime-technology.com/forums/topic/57181-real-Docker-faq/?page=2#comment-566100)):
        ```
        docker run --rm -t -i --device=/dev/snd/ phusion/baseimage:0.9.22 /sbin/my_init -- bash -l
        ```
        login to running docker:
        ```
        docker ps
        docker exec -t -i YOUR-CONTAINER-ID bash -l
        ```
    1. Install packages:
        ```
        apt-get -qq -y update && apt-get -qq -y install wget usbutils alsa-base alsa-utils
        ```
    1. Test if sound card working in Docker container (playing [sound test files](http://www.kozco.com/tech/soundtests.html)):
        ```
        wget http://www.kozco.com/tech/piano2.wav -P /home/
        aplay -D default:SND_A /home/piano2.wav
        aplay -D default:SND_B /home/piano2.wav
        ```
    1. Set volume via *amixer* (alternative: use *alsamixer*):
        ```
        # capture: cap/nocap; muting: mute/unmute
        # mic
        amixer -D hw:CARD=SND_A sset Speaker 80% mute # CSL
        amixer -D hw:CARD=SND_A sset Mic 80% cap mute # CSL
        # line in
        amixer -D hw:CARD=SND_B sset Speaker 80% mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset Mic 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset Line 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset PCM 80% cap mute # DIGIFLEX
        amixer -D hw:CARD=SND_B sset 'PCM Capture Source' Line # DIGIFLEX
        ```
    1. Record from mic/line in:
        ```
        arecord -D hw:CARD=SND_A -d 10 -r 44100 -f S16_LE > /home/sample.wav # mono mic in
        arecord -D hw:CARD=SND_B -d 10 -f CD > /home/sample.wav # stereo line in
        aplay -D default:SND_A /home/sample.wav
        ```
1. [How Do I Create My Own Docker Templates?](https://lime-technology.com/forums/topic/57181-real-Docker-faq/#comment-566084)
