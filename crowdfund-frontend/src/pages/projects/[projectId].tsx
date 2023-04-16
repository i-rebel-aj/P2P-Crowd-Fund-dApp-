import { useRouter } from "next/router"
export default function ProjectById(){
    const router=useRouter()
    const projectId=router.query.projectId
    return (<>
            <h1>Showing project {projectId}</h1>
        </>)
}