from google.cloud import iam_admin_v1


def create_role(project_id, role_id):
    client = iam_admin_v1.IAMClient()

    # El recurso donde vive el rol. Va en plural: projects/ID
    parent = f"projects/{project_id}"

    role = iam_admin_v1.Role(
        title="VM Starter Stopper",
        included_permissions=["compute.instances.start", "compute.instances.stop"],
        # GA = rol estable. El enum está anidado dentro de Role.
        stage=iam_admin_v1.Role.RoleLaunchStage.GA,
    )

    request = iam_admin_v1.CreateRoleRequest(
        parent=parent,
        role_id=role_id,
        role=role,
    )
    response = client.create_role(request=request)
    print(f"Rol creado : {response.name}")
    return response


if __name__ == "__main__":
    create_role("gcp-data-engineer-muestra", "vmStarterStopper")
