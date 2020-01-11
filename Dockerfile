ARG IMAGE_base=bionic
ARG build_G4Version="10.05.p01"
ARG build_shortG4version="10.5.1"	
ENV G4Version=$build_G4Version
ENV shortG4version=$build_shortG4version
FROM ubuntu:${IMAGE_base} as base

LABEL maintainer="Further Lin <55025025+ifurther@users.noreply.github.com>"

RUN sed --in-place --regexp-extended "s/(\/\/)(archive\.ubuntu)/\1tw.\2/" /etc/apt/sources.list && \
	apt-get update && apt-get upgrade --yes

RUN apt-get update

RUN apt-get install -y libexpat1-dev libgl1-mesa-dev \
libglu1-mesa-dev libxt-dev xorg-dev build-essential \
libxerces-c-dev libxmu-dev expat libfreetype6-dev  \
cmake-curses-gui wget libxext-dev qt5-default \
git dpkg-dev libfftw3-dev libftgl-dev python-dev \
libexpat-dev zlib1g zlib1g-dev

RUN apt-get clean all


FROM base as geant4-build

SHELL ["/bin/bash", "-c"] 
RUN if [ ! -e /app ] ; then mkdir /app; fi
RUN if [ ! -e /src ];then mkdir /src;fi
ENV G4WKDIR=/app

WORKDIR /app

RUN echo "G4WKDIR is: ${G4WKDIR}"

RUN bash -c 'mkdir -p ${G4WKDIR}/geant4.${shortG4version}-install/share/data/Geant4-${shortG4version}'
#ADD Geant4-${shortG4version}/*.tar.gz ${G4WKDIR}/geant4.${shortG4version}-install/share/Geant4-${shortG4version}/data/
#ADD geant4.${G4Version}.tar.gz .
RUN if [ ! -e geant4.${G4Version} ] ; then wget http://geant4-data.web.cern.ch/geant4-data/releases/geant4.${G4Version}.tar.gz; \
tar zxvf geant4.${G4Version}.tar.gz -C ${G4WKDIR}; \
rm -rf geant4.${G4Version}.tar.gz; fi


RUN bash -c 'if [ -e geant4.${shortG4version}-install ] ; then mkdir ${G4WKDIR}/geant4.${shortG4version}-build; else mkdir ${G4DIR}/geant4.${shortG4version}-{build,install}; fi'

RUN mkdir ${G4WKDIR}/data && cp ${G4WKDIR}/geant4.${G4Version}/cmake/Modules/Geant4DatasetDefinitions.cmake ${G4WKDIR}/data 
COPY genanddowndata.py ${G4WKDIR}/data
RUN  cd ${G4WKDIR}/data && python genanddowndata.py Geant4DatasetDefinitions.cmake

RUN cd ${G4WKDIR}/geant4.${shortG4version}-build && \
cmake -DCMAKE_INSTALL_PREFIX=${G4DIR}/geant4.${shortG4version}-install \
-DGEANT4_USE_OPENGL_X11=ON -DGEANT4_INSTALL_DATA=ON \
-DGEANT4_USE_QT=ON -DGEANT4_USESYSTEM_ZLIB=ON -DGEANT4_USESYSTEM_EXPAT=ON ${G4WKDIR}/geant4.${G4Version} &&\
make -j`grep -c ^processor /proc/cpuinfo` &&\
make install 

RUN ls $G4WKDIR/geant4.${shortG4version}-install



FROM base as geant4-base

SHELL ["/bin/bash", "-c"] 
RUN if [ ! -e /app ] ; then mkdir /app; fi
RUN if [ ! -e /src ];then mkdir /src;fi
RUN if [ ! -e /app/data ];then mkdir /src;fi
ENV G4WKDIR=/app

WORKDIR /app
RUN echo "G4WKDIR is: ${G4WKDIR}"

RUN  echo  -e "\n\
#!/bin/bash\n\
set -e \n\
\n\
source $G4DIR/bin/geant4.sh\n\
source $G4DIR/share/Geant4-$shortG4version/geant4make/geant4make.sh \n\
\n\
exec "$@" \n
if <condition> ; then \n
  echo "Game over!" \n
  exit 1 \n
fi">$G4WKDIR/entry-point.sh

RUN chmod +x $G4WKDIR/entry-point.sh

COPY --from=geant4-build /$G4WKDIR/geant4.${shortG4version}-install $G4WKDIR/geant4.${shortG4version}-install

COPY --from=geant4-build ${G4WKDIR}/geant4.${G4Version} /src

COPY --from=geant4-build ${G4WKDIR}/data/downdata.sh /data

ENTRYPOINT ["/entrypoint.sh"]
