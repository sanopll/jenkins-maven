horbor_addr=$1
horbor_repo=$2
project=$3
version=$4
port=$5

imageName=$horbor_addr/$horbor_repo/$project:$version

echo $imageName

containerId=`docker ps -a | grep ${project} | awk "{print $1}"`

echo $containerId 

if [ "$containerId" != "" ] ; then
   docker stop $containerId
   docker rm $containerId
fi

image_tag=`docker images | grep ${project} | awk "{print $2}"`

echo $image_tag

if [[ "$tag" =~ "$version" ]] ; then
   docker rmi -f $imageName
fi

docker login -u admin -p Harbor12345 $horbor_addr

docker pull $imageName

docker run -d -p $port:$port --name $project $imageName

echo "SUCCUSS"
