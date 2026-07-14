#define _GNU_SOURCE
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <linux/reboot.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static volatile sig_atomic_t reap=0,halt=0;static void sig(int s){if(s==SIGCHLD)reap=1;else halt=s;}static void logx(const char*f,...){va_list a;va_start(a,f);dprintf(1,"[init] ");vdprintf(1,f,a);dprintf(1,"\n");va_end(a);}static int xmkdir(const char*p){mkdir(p,0755);return 0;}static int spawn(const char*p,char*const v[]){pid_t q=fork();if(!q){setsid();execv(p,v);dprintf(2,"exec %s failed\n",p);_exit(127);}return q;}static int spawn_env(const char*p,char*const v[],char*const e[]){pid_t q=fork();if(!q){setsid();execve(p,v,e);dprintf(2,"exec %s failed\n",p);_exit(127);}return q;}static void mnt(const char*t,const char*p,const char*fs,unsigned long fl,const char*o){xmkdir(p);if(mount(t,p,fs,fl,o)&&strcmp(fs,"devtmpfs"))logx("mount %s on %s failed",fs,p);}int main(){if(getpid()!=1)return dprintf(2,"must be pid1\n"),1;sigset_t z;sigemptyset(&z);struct sigaction sa={.sa_handler=sig,.sa_mask=z,.sa_flags=SA_RESTART|SA_NOCLDSTOP};sigaction(SIGCHLD,&sa,0);sigaction(SIGTERM,&sa,0);sigaction(SIGINT,&sa,0);sigaction(SIGPWR,&sa,0);mnt("proc","/proc","proc",0,"");mnt("sysfs","/sys","sysfs",0,"");mnt("devtmpfs","/dev","devtmpfs",0,"mode=0755");xmkdir("/run");xmkdir("/tmp");mount("tmpfs","/run","tmpfs",0,"mode=0755");mount("tmpfs","/tmp","tmpfs",0,"mode=1777");int c=open("/dev/console",O_RDWR|O_NOCTTY);if(c>=0){dup2(c,0);dup2(c,1);dup2(c,2);if(c>2)close(c);}logx("boot");char*net[]={"/etc/init.d/net",0},*stor[]={"/etc/init.d/storage",0},*wd[]={"/sbin/watchdog",0},*md[]={"/sbin/cactus-modeld",0},*cx[]={"/sbin/cortex",0},*sh[]={"/bin/sh",0};char*me[]={"CORTEX_MODEL_SOCK=/run/cortex-model.sock","PATH=/sbin:/bin:/usr/sbin:/usr/bin",0};char*ce[]={"CORTEX_SOCK=/run/cortex-model.sock","PATH=/sbin:/bin:/usr/sbin:/usr/bin",0};spawn(net[0],net);spawn(stor[0],stor);spawn(wd[0],wd);spawn_env(md[0],md,me);pid_t cortex=spawn_env(cx[0],cx,ce);for(;;){pause();if(reap){int st;pid_t p;reap=0;while((p=waitpid(-1,&st,WNOHANG))>0){logx("child %d exit %d",p,st);if(p==cortex)cortex=spawn(cx[0],cx);}}if(halt){logx("halt signal %d",halt);sync();reboot(LINUX_REBOOT_CMD_POWER_OFF);spawn(sh[0],sh);}}}
