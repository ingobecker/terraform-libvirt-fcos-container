# terraform libvirt fedora coreos container image

This image contains terraform as well as the
[terraform-provider-libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)
, [terraform-provider-ct](https://github.com/poseidon/terraform-provider-ct)
and [coreos-installer](https://github.com/coreos/coreos-installer). You can use
it to setup `fedora coreos` based virtual machines using libvirt, ignition and terraform.

It is recommended to run this image using fedora since it ships with podman and
udica which are required. All instructions of this README are written to be
used on a fedora based system >= 31.

For an example, which can be used with this image to provision gitlab-runners,
see the [ingobecker/tf-libvirt-fcos-gitlab-runner](https://github.com/ingobecker/tf-libvirt-fcos-gitlab-runner).

## Prepare

To run this image as an unprivileged user, make sure your user is member of the
`libvirt` group in order to access the libvirt socket. Furthermore, load the
supplied `terraform_libvirt_container.cil`:

```
$ sudo dnf install udica
$ sudo semodule -i terraform_libvirt_container.cil /usr/share/udica/templates/{base_container.cil,net_container.cil,virt_container.cil}
```
This allows the container to access the bind mounted libvirt socket.

## Build

```
$ podman build -t terraform-libvirt .
```

If you have a local state directory that you want to access inside the container you can include it into the runlabel like this:

```
$ podman build -t terraform-libvirt --build-arg state_volume="-v~/tf-state-dir:/terraform-state:Z" .
```

## Run

Change into the directory of your terraform root module. Run the following command:

```
$ podman container runlabel shell terraform-libvirt
```

This starts an interactive shell inside of the container and mounts the current working directory to `/home/deploy/src`. To apply your module, run:

```
[deploy@terraform-libvirt src]$ terraform init && terraform apply
```

This container includes the `libvirt-client` package so you can run

```
[deploy@terraform-libvirt src]$ virsh list --all
```

and similar commands to inspect the state of libvirtd.
