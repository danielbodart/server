FROM gameservermanagers/gameserver:mcb

# This doesn't work because the /data directory is a volume
# And if you put it in the /app directory the symlink fails to be created
COPY common.cfg /data/config-lgsm/mcbserver/common.cfg